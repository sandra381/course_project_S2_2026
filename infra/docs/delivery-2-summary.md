# Delivery 2 — Compute, Storage, Database & Remote State

## 1. Compute Target and Rationale
El equipo decidió utilizar AWS Lambda como servicio de cómputo para el SPVR (Sistema de Procesamiento de Ventas y Reportes). Esta decisión se mantiene con respecto al Delivery 1, ya que Lambda se adapta muy bien al funcionamiento del sistema. Cuando el analista sube un archivo CSV al bucket de Amazon S3, la función Lambda se ejecuta automáticamente para procesar la información, generar el reporte PDF y continuar con el flujo del sistema. Además, como Lambda solo genera costos cuando realmente se ejecuta, resulta una opción conveniente para un sistema que no procesa archivos de manera continua.

La función se configuró con 512 MB de memoria, ya que el procesamiento de archivos CSV con miles de registros y la generación de reportes PDF requieren más recursos que la configuración mínima de 128 MB. También se estableció un timeout de 30 segundos, tiempo suficiente para procesar los archivos previstos en esta etapa del proyecto.

**Trade-off considerado — AWS Lambda vs Amazon EC2 y AWS Fargate:**

AWS Lambda tiene un límite máximo de 15 minutos por ejecución, mientras que Amazon EC2 y AWS Fargate permiten ejecutar procesos durante más tiempo y ofrecen un mayor control sobre el entorno de ejecución. Sin embargo, para este proyecto ese límite no representa una restricción, ya que los archivos CSV que se procesarán son de tamaño moderado y el tiempo requerido para generar los reportes es relativamente corto.

Se eligió Lambda porque se integra de forma natural con Amazon S3, Amazon SQS y Amazon SES, escala automáticamente y no requiere administrar servidores ni contenedores. Esto simplifica considerablemente la arquitectura y reduce el esfuerzo operativo del equipo.

El trade-off aceptado es que, si en el futuro se necesita procesar archivos mucho más grandes o tareas que superen los 15 minutos de ejecución, será necesario migrar este componente a Fargate o EC2, que ofrecen mayor flexibilidad para cargas de trabajo más pesadas.

---

## 2. Module Design

Se crearon tres módulos reutilizables en `infra/modules/`:

### Módulo Compute (`infra/modules/compute/`)

**Inputs:** `environment`, `name`, `memory_size`, `timeout`, `project_name`, `s3_bucket_arn`

**Outputs:** `function_arn`, `function_name`, `role_arn`

El módulo crea la función AWS Lambda, su rol IAM y una política de permisos mínimos. El rol solo permite leer y escribir archivos en el bucket S3 de entrada (acciones `s3:GetObject` y `s3:PutObject`), además de escribir logs en CloudWatch Logs para monitoreo y diagnóstico.

### Módulo Storage (`infra/modules/storage/`)

**Inputs:** `environment`, `project_name`, `bucket_name`

**Outputs:** `bucket_arn`, `bucket_name`, `bucket_url`

El módulo es reutilizable y se invoca dos veces desde Terraform para crear dos buckets S3: `oyd-project-dev-files` (almacena los CSV subidos por el analista) y `oyd-project-dev-reports` (guarda los PDF generados). Esta separación facilita organizar la información y aplicar permisos específicos por propósito.

### Módulo Database (`infra/modules/database/`)

**Inputs:** `environment`, `project_name`, `db_name`, `db_username`, `db_password`,
`instance_class`, `multi_az`, `subnet_ids`, `vpc_id`

**Outputs:** `db_endpoint`, `db_name`, `db_port`, `security_group_id`

El módulo crea una instancia de Amazon RDS con MySQL, incluyendo un subnet group (subredes privadas de la VPC), un parameter group (configuración personalizada) y un security group que solo permite acceso al puerto 3306 a recursos internos autorizados. Así, la base de datos queda aislada de Internet y solo puede ser usada por componentes internos como la función Lambda.

### Decisión de diseño — conexión entre módulos

La decisión más importante fue exponer `bucket_arn` como output del módulo storage
y pasarlo como input `s3_bucket_arn` al módulo compute. Esto permite que el rol IAM
de Lambda tenga permisos exactamente sobre el bucket de archivos CSV, sin hardcodear
ningún ARN. El root module actúa como el conector entre los módulos:

```
module "compute" {
  ...
  s3_bucket_arn = module.storage_files.bucket_arn
}
```

---

## 3. Remote State Migration

Se creó un workspace de bootstrap en `infra/bootstrap/` con state local. Este
workspace provisiona el bucket S3 y la tabla DynamoDB para el locking del state,
con `prevent_destroy = true` en ambos recursos para evitar destrucciones accidentales.

**Pasos seguidos para la migración:**

1. Se corrió `terraform init` y `terraform apply` en `infra/bootstrap/`
2. Se obtuvo el output con `terraform output`
3. Se configuró `infra/backend.tf` con los valores hardcodeados del output
4. Se corrió `terraform init` en `infra/` — Terraform migró el state automáticamente

**Recursos del backend:**

| Recurso | Nombre |
|---|---|
| Bucket S3 | `oyd-project-terraform-state-2026` |
| Región | `us-east-1` |

**Output de `terraform init` confirmando la migración:**

```
Initializing the backend...
Successfully configured the backend "s3"!
Terraform has been successfully initialized!
```

El state local fue removido de `infra/` y agregado al `.gitignore` junto con
`*.tfvars` y `.terraform/` para evitar que se commiteen accidentalmente.

---

## 4. Database Security

Las credenciales de la base de datos se manejan de la siguiente manera:

- `db_password` está definida en `infra/variables.tf` con `sensitive = true`.Terraform nunca muestra este valor en logs, en el plan ni en los outputs.
- El valor real de la contraseña se pasa únicamente en `envs/dev/dev.tfvars`,
  archivo que está incluido en `.gitignore` y nunca se commitea al repositorio.
- En el pipeline de CI, las credenciales se inyectan como secrets de GitHub
  (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) nunca aparecen en el código.

**Restricción de acceso a la base de datos:**

El security group de RDS (`oyd-project-dev-rds-sg`) solo permite conexiones
entrantes en el puerto 3306 (MySQL) desde el rango CIDR de la VPC (`172.31.0.0/16`).
No existe ninguna regla de ingreso con `0.0.0.0/0`. Esto garantiza que la base de
datos solo es accesible desde recursos dentro de la misma VPC en producción,
únicamente desde la capa de cómputo.

---

## 5. Architectural Trade-offs

### Trade-off 1 — VPC default vs VPC propia para RDS

Se decidió usar la VPC default de AWS para el Delivery 2 en lugar de crear una VPC
propia. Esto simplifica la configuración y permite desplegar RDS sin necesidad de
definir subnets, route tables ni NAT gateways que son componentes que se cubrirán en el
Delivery 3. El trade-off aceptado es que la VPC default no tiene separación entre
subnets públicas y privadas, por lo que RDS queda en una subnet que técnicamente
tiene acceso a internet, aunque está protegida por el security group. En el Delivery 3
se migrará a una VPC propia con subnets privadas dedicadas para la base de datos,
siguiendo el principio de separación de capas.

### Trade-off 2 — RDS MySQL vs DynamoDB para la base de datos del sistema

El equipo evaluó Amazon DynamoDB como alternativa a Amazon RDS con MySQL. DynamoDB ofrece una configuración más sencilla en Terraform, ya que no requiere definir subnet groups, parameter groups ni security groups, y además escala automáticamente. Sin embargo, el sistema SPVR maneja información con relaciones claras entre usuarios, trabajos, reportes y errores, y necesita consultas como obtener los jobs de un usuario, filtrar reportes por período y registrar errores asociados a un trabajo específico. Este tipo de patrones de acceso se modela de forma natural en MySQL mediante consultas SQL estándar, mientras que en DynamoDB sería necesario diseñar múltiples índices secundarios globales (GSI), lo que incrementaría la complejidad del modelo y podría generar costos adicionales. Por estas razones, se decidió utilizar Amazon RDS con MySQL, no solo porque se ajusta mejor a la naturaleza relacional del sistema, sino también porque el equipo ya cuenta con experiencia previa trabajando con esta plataforma, lo que facilita el diseño, implementación y mantenimiento de la solución.