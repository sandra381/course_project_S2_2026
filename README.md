# SPVR — Sistema de Procesamiento de Ventas y Reportes

Proyecto académico desarrollado para los cursos Infraestructura en la Nube y Optimización y Desempeño (OYD) — Postgrado en Diseño y Desarrollo de Software, Universidad Galileo (FISICC).

Equipo: Sandra Soria, Gabriela Navarro, Diego Sican

---

## ¿Qué es SPVR?

SPVR es una aplicación web que permite a una empresa procesar archivos CSV de ventas y generar automáticamente reportes en PDF con métricas de negocio (productos más vendidos, clientes frecuentes, ventas por ciudad, evolución mensual y desempeño individual por vendedor).

```
Usuario sube un CSV de ventas
        ↓
El sistema lo procesa en segundo plano (sin bloquear al usuario)
        ↓
Se genera un PDF con el análisis completo
        ↓
El analista recibe un correo con el enlace de descarga
```

La aplicación tiene 5 roles distintos, cada uno con su propia vista y permisos:

| Rol | Qué puede hacer |
|---|---|
| **Analista** | Sube CSVs, ve sus propios reportes, descarga PDFs |
| **Vendedor** | Ve su desempeño de ventas (ranking, productos, evolución) |
| **Gerente** | Ve el historial completo de reportes de todos los analistas |
| **Auditor** | Ve y descarga cualquier reporte y su CSV original, sin poder modificar nada |
| **Administrador** | Monitorea el sistema completo y el registro de errores |

---

## Arquitectura técnica

Todo corre 100% en AWS, sin servidores que administrar (serverless), provisionado completamente con Terraform.

```
                         Internet
                            │
                            ▼
                      CloudFront (HTTPS + redirect)
                            │
                            ▼
                      API Gateway (HTTP API)
                            │
                            ▼
                      Lambda API ──────► RDS MySQL
                            │                 ▲
                            ▼                 │
                      SQS Queue ──► Lambda Worker
                            │                 │
                            ▼                 ▼
                          DLQ          S3 (CSVs + PDFs)
                                              │
                                              ▼
                                        Amazon SES (correo)
```

**Stack:** AWS Lambda (Python 3.12), API Gateway, RDS MySQL, S3, SQS, CloudFront, Route 53, ACM, KMS, Secrets Manager, CloudWatch, SNS, SES — todo gestionado con Terraform.

**Frontend:** React + Vite, consumiendo la API vía HTTPS.

---

## Estructura del repositorio

```
.
├── .github/workflows/          ← Pipeline de CI/CD (GitHub Actions)
│   ├── terraform-ci.yml        ← fmt, validate, plan en cada PR; apply al mergear a main
│   ├── terraform-destroy.yml   ← Destroy manual de un ambiente (workflow_dispatch)
│   └── terraform-drift.yml     ← Detección diaria de drift entre AWS y el código
│
├── frontend/                   ← Aplicación React (interfaz de usuario)
│   └── src/
│       ├── pages/               ← Una pantalla por vista (Dashboard, Login, History, etc.)
│       ├── api/                 ← Cliente HTTP que conecta con la API real de AWS
│       └── components/          ← Componentes reutilizables de UI
│
├── infra/                      ← Todo el código de infraestructura (Terraform)
│   ├── bootstrap/               ← Backend remoto del state (S3 + DynamoDB), se aplica una sola vez
│   ├── modules/                  ← Módulos reutilizables
│   │   ├── network/             ← VPC, subredes, NAT, security groups
│   │   ├── compute/              ← Lambda API + Worker, layers, handlers Python
│   │   ├── database/             ← RDS MySQL
│   │   ├── storage/               ← Buckets S3
│   │   ├── async/                  ← SQS + Dead Letter Queue
│   │   ├── ingress/                ← API Gateway
│   │   ├── scheduler/               ← Lambda Cleanup + EventBridge Scheduler
│   │   ├── iam/                      ← Roles, OIDC provider, políticas
│   │   ├── secrets/                   ← KMS + Secrets Manager
│   │   └── observability/             ← CloudWatch, SNS, Budgets
│   ├── envs/                      ← Variables específicas por ambiente
│   │   ├── dev/
│   │   └── staging/
│   ├── docs/                      ← Resúmenes escritos de cada entrega
│   │   ├── delivery-1-summary.md  … delivery-4-summary.md
│   │   ├── delivery-5-summary.md
│   │   └── iac-coverage.md         ← Auditoría de cobertura de IaC (Deliverable I)
│   ├── evidence/                   ← Capturas y outputs como evidencia de cada entregable
│   ├── database/schema.sql         ← Esquema de referencia de la base de datos
│   ├── *.tf                         ← Recursos del workspace principal (acm, cloudfront, dns, etc.)
│   └── README.md                    ← Runbook técnico + evidencia detallada por entregable
│
├── nube/                        ← Documentos PDF de las entregas del curso Infraestructura en la Nube
│
└── README.md                    ← Este archivo
```

---

## Cómo correr el proyecto

### 1. Infraestructura (ya desplegada en AWS)

La infraestructura completa ya está provisionada y corriendo. Para verificarla o redesplegarla desde cero:

```bash
cd infra/
terraform init -reconfigure -backend-config=envs/dev/backend-dev.hcl
terraform output
```

Ver `infra/README.md` para el Runbook completo (permisos necesarios, secrets de GitHub, cómo disparar el pipeline de CI/CD).

### 2. Inicializar los datos de la aplicación (una sola vez)

```bash
curl -X POST https://api.grupo1.oyd.solid.com.gt/setup
```

Esto crea las tablas de la base de datos y los 9 usuarios de prueba.

### 3. Frontend (local)

```bash
cd frontend/
npm install
```

Crear un archivo `.env` con:
```
VITE_API_URL=https://api.grupo1.oyd.solid.com.gt
```

```bash
npm run dev
```

Abrir `http://localhost:3000`.

---

## Usuarios de prueba

Todos los usuarios usan el dominio de prueba `@spvr.com` o `sandra.soria+nombre@galileo.edu` (solo los analistas reciben correos reales, por la restricción de modo Sandbox de Amazon SES).

| Rol | Email | Contraseña |
|---|---|---|
| Analista | `sandra.soria+ana@galileo.edu` | `Ana2026!` |
| Analista | `sandra.soria+mariajulia@galileo.edu` | `Maria2026!` |
| Analista | `sandra.soria+pablo.juarez@galileo.edu` | `Pablo2026!` |
| Vendedor | `miguelpaz@spvr.com` | `Miguel2026!` |
| Vendedor | `javier.hernandez@spvr.com` | `Javier2026!` |
| Vendedor | `consuelo.paiz@spvr.com` | `Consuelo2026!` |
| Gerente | `andrea.gomez@spvr.com` | `Andrea2026!` |
| Administrador | `santiago.lopez@spvr.com` | `Santiago2026!` |
| Auditor | `valentina.rodriguez@spvr.com` | `Valentina2026!` |

Estas son credenciales de demostración académica únicamente — nunca usar este patrón en un sistema real en producción.

---

## Formato esperado del CSV de ventas

```csv
sale_id,sale_date,product_name,quantity,unit_price,city,salesperson_name,customer_id,customer_name
1,2026-04-01,Laptop Pro X15,2,9500.00,Guatemala,Miguel Paz,101,Comercial Reyes S.A.
```

El sistema valida estas columnas antes de aceptar el archivo.

---

## Documentación por curso

### Infraestructura en la Nube (Deliveries 1–5)

Establece la arquitectura base de la aplicación: VPC con subredes públicas/privadas, funciones Lambda (API y Worker), base de datos RDS MySQL, buckets S3, cola SQS con Dead Letter Queue, y API Gateway. Documentos de cada entrega en `nube/`.

### Optimización y Desempeño — OYD (Deliveries 1–5)

Automatiza y asegura la infraestructura anterior mediante Terraform: estructura de módulos reutilizables, backend remoto de estado (S3 + DynamoDB), y un pipeline de CI/CD con GitHub Actions. A lo largo de las 5 entregas se incorporó seguridad con mínimo privilegio (IAM, KMS, Secrets Manager), autenticación OIDC sin credenciales de larga vida, TLS/HTTPS con CloudFront y ACM, observabilidad (CloudWatch, alarmas, dashboard, presupuesto), una prueba de despliegue de un solo click, y una auditoría completa de cobertura de IaC.

Resúmenes de cada entrega en `infra/docs/delivery-N-summary.md`. El detalle completo del Delivery 5 (la entrega más reciente) está en `infra/README.md` y `infra/docs/delivery-5-summary.md`.

---

## Notas importantes

- **Pipeline CI/CD:** cada Pull Request corre `fmt`, `validate` y `plan` automáticamente vía GitHub Actions. El merge a `main` despliega a `dev` automáticamente.
- **Sin credenciales de larga vida:** el pipeline se autentica con AWS vía OIDC (sin access keys almacenadas en GitHub).
- **Modo Sandbox de SES:** solo los 3 emails de analistas están verificados para recibir correo; el resto de roles funciona sin notificación por correo.
