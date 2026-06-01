# Delivery 3 — Networking Layer Summary

## 1. Networking Track and Rationale

El equipo está en el VPC-Required Track. Esta decisión se basa en los servicios seleccionados en el Delivery 2:

- **Compute:** AWS Lambda (Python 3.12)
- **Database:** Amazon RDS MySQL 8.0 (`db.t3.micro`)

Aunque Lambda es serverless, la guía establece que el track serverless-only aplica únicamente cuando tanto el compute como la base de datos son completamente serverless (Lambda + DynamoDB, o Cloud Functions + Firestore). Al usar RDS MySQL, el equipo cae automáticamente en el VPC-Required Track.

### Diseño CIDR

| Recurso | CIDR | Availability Zone |
|---|---|---|
| VPC | `10.0.0.0/16` | — |
| Public Subnet A | `10.0.1.0/24` | us-east-1a |
| Public Subnet B | `10.0.2.0/24` | us-east-1b |
| Private Subnet A | `10.0.11.0/24` | us-east-1a |
| Private Subnet B | `10.0.12.0/24` | us-east-1b |

El bloque `10.0.0.0/16` fue seleccionado porque ofrece una capacidad amplia para organizar la red en distintas subredes desde las primeras etapas del proyecto. Esta estructura permite mantener una distribución ordenada de los recursos y facilita la administración de la infraestructura.

Cada subnet utiliza un bloque `/24`, lo cual proporciona un espacio de direccionamiento adecuado para los componentes contemplados actualmente. Además, la solución se despliega en dos Availability Zones dentro de la región `us-east-1`, con el objetivo de mejorar la disponibilidad y reducir el impacto ante una posible falla en una de las zonas.

### Decisión NAT: Single NAT Gateway

Se eligió un single NAT Gateway ubicado en `Public Subnet A (us-east-1a)`. La justificación es que el proyecto tiene alcance académico y carga baja, por lo que el costo adicional de un NAT Gateway por AZ (~$32/mes adicional) no se justifica en esta etapa. En un ambiente productivo con requerimientos de alta disponibilidad, se evaluaría un NAT Gateway por AZ.

---

## 2. Module and Architecture Design

### Módulo `infra/modules/network/`

**Estructura:**
```
infra/modules/network/
├── main.tf       — VPC, IGW, subnets, NAT, route tables, SGs, NACLs
├── variables.tf  — CIDRs, AZs, NAT topology, nombres
└── outputs.tf    — vpc_id, subnet IDs, SG IDs, NAT IDs
```

**Inputs que acepta:**

| Variable | Descripción |
|---|---|
| `vpc_cidr` | CIDR block de la VPC |
| `public_subnet_cidrs` | Lista de CIDRs para subnets públicas |
| `private_subnet_cidrs` | Lista de CIDRs para subnets privadas |
| `availability_zones` | Lista de AZs donde se despliegan las subnets |
| `single_nat_gateway` | Topología del NAT Gateway: `true` para uno compartido, `false` para uno por AZ |
| `project_name` | Prefijo para nombrar recursos |
| `environment` | Ambiente de despliegue (dev/prod) |

**Outputs que expone:**

| Output | Uso |
|---|---|
| `vpc_id` | Consumido por módulo database y compute |
| `public_subnet_ids` | IDs de subnets públicas |
| `private_subnet_ids` | Consumido por módulos database y compute |
| `nat_gateway_ids` | IDs de NAT Gateways creados |
| `web_sg_id` | Consumido por módulo ingress |
| `app_sg_id` | Consumido por módulo compute |
| `db_sg_id` | Consumido por módulo database |

### Cómo los módulos consumen el network module

El módulo `database` recibe `subnet_ids`, `vpc_id` y `db_sg_id` desde los outputs del network module:

```hcl
module "database" {
  subnet_ids = module.network.private_subnet_ids
  vpc_id     = module.network.vpc_id
  db_sg_id   = module.network.db_sg_id
}
```

El módulo `compute` recibe `subnet_ids` y `security_group_ids` para colocar las funciones Lambda dentro de la VPC:

```hcl
module "compute" {
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.app_sg_id]
}
```

---

## 3. D2 Wiring Update

En el Delivery 2, el módulo database utilizaba la VPC default de AWS mediante data sources:

```hcl
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" { ... }
```

En el Delivery 3 estos data sources fueron eliminados completamente y reemplazados por los outputs del nuevo módulo network. El módulo database ahora recibe:

- `subnet_ids` → `module.network.private_subnet_ids`
- `vpc_id` → `module.network.vpc_id`
- `db_sg_id` → `module.network.db_sg_id`

El security group de RDS que tenía el CIDR hardcodeado `172.31.0.0/16` fue eliminado y reemplazado por el `db_sg_id` gestionado por el módulo network con reglas SG-to-SG.

### Terraform output mostrando VPC ID y subnet IDs

```
vpc_id              = "vpc-0c59775fdbab20e28"
private_subnet_ids  = ["subnet-0802e5de8db9be059", "subnet-05ff07765aed58825"]
public_subnet_ids   = ["subnet-07717579197f633e0", "subnet-05de1763255e40b45"]
nat_gateway_ids     = ["nat-0e55f11c3ae4ecc29"]
```

---

## 4. Security

### Estrategia SG-to-SG (VPC-Required Track)

Se definieron tres security groups con reglas de referencia SG-to-SG en lugar de rangos CIDR para el tráfico inter-tier. La razón de usar referencias a security groups en lugar de CIDRs es que los rangos CIDR son estáticos y requieren mantenimiento manual cuando cambian las IPs de los recursos. En cambio, las referencias SG-to-SG son dinámicas — cualquier recurso que pertenezca al security group referenciado puede comunicarse, sin importar su IP.

- **`web-sg`**: permite HTTP (80) y HTTPS (443) desde `0.0.0.0/0`. Es el punto de entrada público del sistema.
- **`app-sg`**: permite inbound únicamente desde `web-sg` en puerto 443 usando `source_security_group_id`. Esto garantiza que solo el tráfico que pase por la capa web llegue a las Lambdas.
- **`db-sg`**: permite inbound únicamente desde `app-sg` en puerto 3306 (MySQL). No tiene ninguna regla `0.0.0.0/0`. Esto asegura que la base de datos solo acepte conexiones desde las funciones Lambda.

Las reglas se definieron como recursos `aws_security_group_rule` separados en lugar de bloques inline para evitar dependencias circulares entre los security groups.

### NACLs (stateless)

Se definieron dos NACLs con reglas stateless explícitas para tráfico inbound y outbound:

**NACL pública (`aws_network_acl.public`):**

| Dirección | Regla | Protocolo | Puerto | Acción |
|---|---|---|---|---|
| Inbound | 100 | TCP | 80 | allow |
| Inbound | 110 | TCP | 443 | allow |
| Inbound | 120 | TCP | Puertos efímeros (respuestas de conexiones salientes) | allow |
| Outbound | 100 | All | All | allow |

**NACL privada (`aws_network_acl.private`):**

| Dirección | Regla | Protocolo | Puerto | Acción |
|---|---|---|---|---|
| Inbound | 100 | TCP | 3306 (MySQL) | allow |
| Inbound | 110 | TCP | Puertos efímeros (respuestas de conexiones salientes) | allow |
| Outbound | 100 | All | All | allow |

Los puertos efímeros son necesarios porque las NACLs son stateless — a diferencia de los security groups, no recuerdan el estado de las conexiones. Cuando Lambda inicia una conexión hacia RDS o hacia S3, la respuesta regresa por un puerto asignado aleatoriamente por el sistema operativo. Si no se permite ese tráfico explícitamente en las reglas inbound, la respuesta es bloqueada y la conexión falla.

---

## 5. End-to-End Connectivity Proof Architecture

### Lenguaje y Runtime

Python 3.12 en AWS Lambda.

### Endpoints implementados

- `GET /jobs` → conecta a RDS MySQL, consulta la tabla `trabajos` y retorna los registros como JSON
- `POST /jobs` → acepta un JSON body, lo escribe como objeto en el bucket S3 `oyd-project-dev-files` y retorna HTTP 201 con el `object_key`

### Flujo de credenciales

```
GitHub Actions repository secret (DB_PASSWORD)
        ↓
  -var="db_password=${{ secrets.DB_PASSWORD }}"
        ↓
  Terraform variable db_password (sensitive = true)
  declarada en infra/variables.tf y infra/modules/compute/variables.tf
        ↓
  aws_lambda_function.api environment variables block
  DB_PASSWORD = var.db_password
        ↓
  handler_api.py: DB_PASSWORD = os.environ["DB_PASSWORD"]
```

La variable `db_password` está declarada con `sensitive = true` en `infra/variables.tf` y `infra/modules/compute/variables.tf`. No aparece en ningún archivo `.tfvars` comprometido en el repositorio.

### IAM Role y ARNs

El IAM execution role `oyd-project-dev-lambda-role` tiene permisos mínimos:

```
ARN del role: arn:aws:iam::121218949493:role/oyd-project-dev-lambda-role

Permisos S3 (scoped al bucket específico):
  - s3:GetObject  → arn:aws:s3:::oyd-project-dev-files/*
  - s3:PutObject  → arn:aws:s3:::oyd-project-dev-files/*

Permisos CloudWatch Logs:
  - logs:CreateLogGroup    → arn:aws:logs:*:*:*
  - logs:CreateLogStream   → arn:aws:logs:*:*:*
  - logs:PutLogEvents      → arn:aws:logs:*:*:*

Permisos VPC (AWS managed policy):
  - arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

No se utilizan ARNs con wildcard (`"Resource": "*"`) para los permisos de S3. El acceso está limitado al bucket `oyd-project-dev-files` específicamente.

### Mecanismo de Seed Data

El seed data está comprometido en el repositorio en `infra/database/schema.sql`. Este archivo contiene:

1. `CREATE TABLE IF NOT EXISTS` para las 4 tablas del schema (`usuarios`, `trabajos`, `reportes`, `errores`)
2. `INSERT INTO usuarios` con el usuario analista de prueba (`ana@empresa.com`, rol `analista`)
3. `INSERT INTO trabajos` con un trabajo de ejemplo en estado `COMPLETADO`

Todos los `INSERT` usan `ON DUPLICATE KEY UPDATE` para que el script sea idempotente y no falle si se ejecuta más de una vez.

Como la RDS está en una subnet privada sin acceso directo desde internet, el schema se aplicó mediante el endpoint `POST /setup` de la Lambda API. Este endpoint ejecuta las mismas instrucciones SQL del archivo `schema.sql` directamente contra RDS desde dentro de la VPC, aprovechando que la Lambda tiene conectividad de red hacia la base de datos a través del `db-sg`.

---

## 6. Architectural Trade-offs

### Trade-off 1: Single NAT Gateway vs. NAT Gateway por AZ

Se eligió un single NAT Gateway en lugar de uno por cada Availability Zone. El NAT Gateway por AZ ofrece mayor tolerancia a fallos — si una AZ falla, las subnets privadas en las otras AZs mantienen conectividad saliente de forma independiente. Sin embargo, el costo de un NAT Gateway es ~$32/mes por unidad, más el costo por GB de datos procesados. Para un proyecto académico con carga baja y dos AZs, el costo adicional no se justifica. Si el sistema evolucionara a un ambiente productivo donde la disponibilidad fuera crítica, se evaluaría un NAT Gateway por AZ para eliminar este punto único de fallo en la conectividad saliente.

### Trade-off 2: NAT Gateway vs. VPC Gateway Endpoint para S3

Se eligió usar el NAT Gateway para que las funciones Lambda accedan a S3, en lugar de configurar un VPC Gateway Endpoint para S3. Un Gateway Endpoint para S3 es gratuito, mantiene el tráfico dentro de la red de AWS y elimina la dependencia del NAT Gateway para acceder a S3. Sin embargo, requiere configuración adicional de route tables y políticas de endpoint. En esta etapa del proyecto, el NAT Gateway ya está presente para otros usos (acceso a internet desde subnets privadas), por lo que agregar un Gateway Endpoint habría aumentado la complejidad sin un beneficio inmediato significativo. En futuras iteraciones se evaluará incorporar el Gateway Endpoint para S3 con el objetivo de reducir costos y mejorar la seguridad del tráfico hacia el bucket.