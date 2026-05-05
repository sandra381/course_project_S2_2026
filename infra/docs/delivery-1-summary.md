# Delivery 1 — IaC Workspace Bootstrap & CI Pipeline
---

## 1. Proveedor de nube y región

El equipo eligió **AWS** como proveedor de nube y **us-east-1 (Norte de Virginia)** como región de despliegue.

Se eligió AWS porque el equipo ya tiene experiencia trabajando con esta plataforma desde el curso de Infraestructura en la Nube. Esto nos permite enfocarnos en automatizar la infraestructura sin perder tiempo aprendiendo una plataforma nueva. Además, AWS tiene el soporte más completo para Terraform, con módulos disponibles para todos los componentes que necesitaremos en las próximas entregas.

La región us-east-1 se eligió porque es la región principal de AWS, tiene disponibilidad de todos los servicios, y es donde más rápido llegan las actualizaciones y nuevas funcionalidades. Además, se realizó una prueba de latencia desde el entorno de desarrollo del equipo usando cloudpingtest.com, confirmando que us-east-1 tiene la menor latencia con **341 ms**, comparado con 502 ms de us-east-2 y 604 ms de us-west-2.

---

## 2. Recurso provisionado

El recurso provisionado en este Delivery es un **bucket de Amazon S3** llamado `oyd-project-app-assets-dev`. Junto con el bucket, se configuraron dos recursos adicionales: versionado y encriptación.

Se eligió un bucket S3 como primer recurso porque es uno de los más simples de crear en AWS — no necesita red privada, ni configuración de subnets, ni roles de IAM complejos. Esto nos permite verificar que el proveedor, las credenciales y las variables están funcionando correctamente sin agregar complejidad innecesaria. El bucket también es parte de la arquitectura final del proyecto, por lo que no es un recurso desechable.

Se activaron el versionado y la encriptación desde el inicio porque son buenas prácticas de AWS y serán requeridos en el Delivery 2. Activarlos ahora evita tener que reemplazar el bucket más adelante.

**Extracto del terraform plan:**

```
Terraform will perform the following actions:

  # aws_s3_bucket.app_assets will be created
  + resource "aws_s3_bucket" "app_assets" {
      + bucket                      = "oyd-project-app-assets-dev"
      + force_destroy               = false
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "oyd-project-app-assets-dev"
          + "Project"     = "oyd-project"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "oyd-project-app-assets-dev"
          + "Project"     = "oyd-project"
        }
    }

  # aws_s3_bucket_server_side_encryption_configuration.app_assets will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
      + rule {
          + apply_server_side_encryption_by_default {
              + sse_algorithm = "AES256"
            }
        }
    }

  # aws_s3_bucket_versioning.app_assets will be created
  + resource "aws_s3_bucket_versioning" "app_assets" {
      + versioning_configuration {
          + status = "Enabled"
        }
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + app_bucket_arn  = (known after apply)
  + app_bucket_name = "oyd-project-app-assets-dev"
```

---

## 3. Arquitectura del pipeline de CI

El pipeline está definido en `.github/workflows/terraform-ci.yml` y se activa automáticamente en cada Pull Request que apunta a la rama `main`. Corre en un servidor Ubuntu y ejecuta cinco pasos en orden.

**Paso 1 — Verificación de formato (`terraform fmt --check -recursive`)**
Revisa que todos los archivos `.tf` tengan el formato correcto según el estándar de Terraform. Si algún archivo está mal formateado, el paso falla y bloquea el PR. El desarrollador debe correr `terraform fmt -recursive` en su computadora y subir la corrección.

**Paso 2 — Inicialización (`terraform init -backend=false`)**
Descarga el plugin del proveedor de AWS y verifica que las versiones definidas en `provider.tf` se resuelvan correctamente. Se usa `-backend=false` porque en esta etapa el estado es local y no hay backend remoto configurado.

**Paso 3 — Validación (`terraform validate`)**
Analiza el código de Terraform sin hacer llamadas a AWS. Detecta errores de tipos, variables faltantes y argumentos incorrectos. Si encuentra algún error, bloquea el PR.

**Paso 4 — Plan (`terraform plan -var-file=envs/dev/dev.tfvars -no-color`)**
Genera un plan real contra la API de AWS usando las variables del ambiente de desarrollo. Este paso requiere credenciales activas y confirma que la configuración puede aplicarse sin errores. La salida del plan se guarda en `plan.txt` para usarla en el siguiente paso. Si el plan falla, el PR queda bloqueado.

**Paso 5 — Publicar el plan como comentario en el PR**
Lee el archivo `plan.txt` y publica su contenido como comentario en el PR usando `actions/github-script@v7`. El contenido se muestra dentro de un bloque colapsable `<details>` para no saturar la vista del PR. Si este paso falla, el PR no se bloquea — el plan ya validó que todo está correcto.

**Estrategia de credenciales:**
Las credenciales de AWS se guardan como secrets cifrados en GitHub (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_REGION`) y se inyectan al runner usando la acción oficial `aws-actions/configure-aws-credentials@v4`. Ninguna credencial aparece en el código ni en archivos versionados. En el Delivery 5 se migrará a OIDC federation, que es más seguro porque no usa llaves de larga duración.

---

## 4. Diseño de variables

Todas las variables están definidas en `infra/variables.tf`. La siguiente tabla describe cada una:

| Variable | Tipo | Descripción | Valor en dev | Valor en prod |
|---|---|---|---|---|
| `environment` | `string` | Identifica el ambiente de despliegue. Solo acepta `dev` o `prod`. Se usa en el nombre de los recursos para separarlos. | `dev` | `prod` |
| `project_name` | `string` | Nombre del proyecto. Se usa como prefijo en todos los recursos para evitar conflictos entre cuentas. | `oyd-project` | `oyd-project` |
| `region` | `string` | Región de AWS donde se crean todos los recursos. | `us-east-1` | `us-east-1` |
| `app_bucket_prefix` | `string` | Parte del nombre del bucket S3. Se combina con `project_name` y `environment` para formar el nombre completo. | `app-assets` | `app-assets` |

La variable más importante es `environment` porque su valor aparece en el nombre de todos los recursos. Por ejemplo, el bucket en dev se llama `oyd-project-app-assets-dev` y en prod se llamaría `oyd-project-app-assets-prod`. Esto garantiza que los recursos de dev y prod nunca se confundan ni compartan datos accidentalmente. Además, `environment` tiene una validación que rechaza cualquier valor que no sea `dev` o `prod`, lo que evita errores de configuración desde el inicio.

---

## 5. Decisiones y justificaciones

### Decisión 1 — Separar el código en varios archivos desde el inicio

Se decidió separar el código de Terraform en cuatro archivos distintos (`provider.tf`, `variables.tf`, `outputs.tf`, `main.tf`) desde el Delivery 1, aunque técnicamente todo podría ir en un solo archivo. La razón es que el proyecto crecerá mucho a lo largo de las cinco entregas — para el Delivery 5 habrá recursos de cómputo, base de datos, red, mensajería, seguridad y observabilidad. Si todo estuviera en un solo archivo desde el inicio, se volvería muy difícil de leer y mantener. Separarlo desde el principio establece una convención clara que todos los miembros del equipo pueden seguir sin necesidad de coordinarse constantemente. También hace las revisiones de código más fáciles: si alguien agrega una variable, el cambio aparece solo en `variables.tf` y no mezclado con cambios en recursos.

### Decisión 2 — Estrategia de versiones para Terraform y el provider de AWS

Se decidió usar el operador `~>` para controlar las versiones de Terraform y del provider de AWS, definiendo `~> 1.8` para Terraform y `~> 5.0` para el provider. Esto significa que el workspace acepta actualizaciones de parches automáticamente, pero nunca un cambio de versión mayor que pueda romper la configuración. Por ejemplo, `~> 5.0` acepta `5.1` o `5.2`, pero nunca `6.0`. El trade-off de esta decisión es que dos miembros del equipo podrían tener versiones ligeramente distintas instaladas si corren `terraform init` en momentos diferentes. Para evitar este problema, el archivo `.terraform.lock.hcl` que genera Terraform automáticamente se versiona en el repositorio, garantizando que todos usen exactamente las mismas versiones, incluyendo el pipeline de CI.
