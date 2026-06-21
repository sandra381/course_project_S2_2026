# Delivery 5 — Security, Observability & One-Click Deployment

**Equipo:** Sandra Soria, Diego Sican, Gabriela Navarro
**Repositorio:** `course_project_S2_2026`
**Tag:** `oyd-delivery-5`

---

## 1. Diseño de IAM y Secrets

### Estructura de roles

Para mejorar la seguridad del proyecto, se centralizó la definición de roles IAM dentro del módulo: `infra/modules/iam/`. Anteriormente, algunos roles estaban definidos en módulos separados como `compute/` y `scheduler/`. Con este cambio, la administración de permisos queda más ordenada y es más fácil aplicar el principio de menor privilegio.

La estructura principal de roles quedó de la siguiente manera:

| Role             | Acciones principales                                                                                                                                                                                                                                                                | Resources                                                                 |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `lambda_api`     | Puede leer y escribir archivos en S3, enviar mensajes a SQS, consultar información de RDS y escribir logs únicamente en su propio log group.                                                                                                                                        | ARNs específicos de cada recurso                                          |
| `lambda_worker`  | Puede recibir y eliminar mensajes de SQS, leer archivos CSV desde S3, guardar reportes PDF en S3 y escribir logs propios.                                                                                                                                                           | ARNs específicos                                                          |
| `lambda_cleanup` | Tiene acceso a VPC y permisos para escribir logs propios.                                                                                                                                                                                                                           | ARNs específicos                                                          |
| `scheduler_exec` | Puede invocar únicamente la función Lambda Cleanup. Este permiso se adjunta desde el módulo `scheduler/` para evitar una dependencia circular con el módulo `iam/`.                                                                                                                 | ARN del Lambda Cleanup                                                    |
| `ci_runner`      | Tiene permisos necesarios para ejecutar Terraform desde GitHub Actions sobre servicios como S3, Lambda, RDS, SQS, API Gateway, EventBridge, ACM, Route53, CloudFront, CloudWatch, SNS y Budgets. También usa `ReadOnlyAccess` para operaciones de lectura requeridas por Terraform. | Permisos limitados cuando es posible; wildcard solo donde AWS lo requiere |

### Cambio principal respecto al enfoque anterior

Antes, las funciones Lambda API y Lambda Worker compartían un único rol llamado `lambda_exec`. Esto provocaba que ambos servicios tuvieran permisos mezclados, aunque no todos fueran necesarios para cada función.
Ahora, cada Lambda tiene su propio rol:

* `lambda_api`
* `lambda_worker`
* `lambda_cleanup`

Esto permite que cada servicio tenga únicamente los permisos que necesita para cumplir su función. De esta manera se aplica de forma más estricta el principio de menor privilegio.

---

### Uso de Secrets Manager en runtime

El módulo `compute` ya no envía la contraseña de la base de datos directamente como variable de entorno en las funciones Lambda. Antes, la contraseña podía llegar a Lambda mediante una variable como: `DB_PASSWORD`.
Ahora, las funciones Lambda reciben únicamente el ARN del secreto: `DB_SECRET_ARN`. Luego, cada handler del proyecto consulta el secreto desde AWS Secrets Manager al iniciar:

* `handler_api.py`
* `handler_worker.py`
* `handler_cleanup.py`

Cada función usa `secretsmanager.get_secret_value()` para obtener la contraseña cuando la necesita. Además, el resultado se guarda en caché dentro del contenedor de ejecución, para evitar consultar el secreto repetidamente en cada invocación. La variable `TF_VAR_db_password` todavía existe dentro del pipeline de CI/CD, pero su uso está limitado. Terraform la necesita únicamente para:
1. Crear la instancia RDS.
2. Guardar el valor inicial dentro de Secrets Manager.

Esto significa que la contraseña viaja desde GitHub Secrets hacia Terraform, y luego hacia RDS y Secrets Manager. Sin embargo, ya no se envía directamente como variable de entorno a las funciones Lambda.

---

## 2. Manejo de la llave KMS

Para proteger la información sensible del proyecto, se creó una llave administrada por el cliente en AWS KMS. Este tipo de llave se conoce como **Customer Managed Key (CMK)**.

Se creó una CMK separada para cada ambiente del proyecto:

* Ambiente dev: `alias/oyd-project-dev-cmk`
* Ambiente staging: `alias/oyd-project-staging-cmk`

Un ejemplo del ARN de la llave en el ambiente de desarrollo es:

`arn:aws:kms:us-east-1:121218949493:key/bd88caed-c30b-4466-a0d8-be67f9977f94`

Esta llave se utiliza para encriptar recursos importantes del sistema, como:
* El bucket S3 donde se almacenan archivos CSV: `oyd-project-dev-files`.
* El bucket S3 donde se almacenan reportes PDF: `oyd-project-dev-reports`.
* La base de datos RDS MySQL: `oyd-project-dev-db`.

### Política de acceso de la llave

La política de la llave KMS fue configurada para limitar quién puede usarla. Esto ayuda a evitar accesos no autorizados y reduce el riesgo de que la llave sea utilizada por servicios o usuarios que no corresponden.
La cuenta root tiene permisos administrativos sobre la llave, como crear, describir o habilitar configuraciones. Sin embargo, no tiene permiso para desencriptar información.
Los roles de Lambda utilizados por el sistema tienen únicamente los permisos necesarios para trabajar con datos encriptados:
* `lambda_api`
* `lambda_worker`
* `lambda_cleanup`

Estos roles solo pueden ejecutar las siguientes acciones:
* `kms:Decrypt`
* `kms:GenerateDataKey`

También se permite el uso de la llave al servicio AWS Secrets Manager. Este servicio tiene permisos específicos para trabajar con secretos encriptados:
* `kms:Decrypt`
* `kms:GenerateDataKey`
* `kms:CreateGrant`

Además, este acceso está condicionado a que la solicitud provenga de la misma cuenta del proyecto.
En conclusión, la configuración cumple con el requisito de seguridad porque no se otorgan permisos generales como `kms:*` ni permisos de desencriptado abiertos para todos los usuarios o servicios. El uso de la llave queda limitado únicamente a los roles y servicios que realmente la necesitan.

---

## 3. Federación OIDC

Para que GitHub Actions pueda autenticarse contra AWS sin usar credenciales estáticas, se configuró federación OIDC.

El provider utilizado fue: `https://token.actions.githubusercontent.com`
Este provider fue creado mediante el recurso: `aws_iam_openid_connect_provider` dentro del archivo: `infra/modules/iam/main.tf`.

### Configuración principal

El valor de `audience claim` configurado fue: `sts.amazonaws.com`.

Inicialmente, se intentó restringir el acceso únicamente a la rama `main` y a eventos de `pull_request`, usando una condición `StringLike` con dos valores distintos:
* `repo:sandra381/course_project_S2_2026:ref:refs/heads/main`
* `repo:sandra381/course_project_S2_2026:pull_request`

Esta configuración generaba errores de autorización de forma constante, aunque la política de permisos del rol estuviera correctamente definida. Como solución temporal mientras se investigaba la causa, se usó un patrón más general a nivel de repositorio: `repo:<org>/<repo>:*`.

### Causa raíz y solución definitiva

Al revisar en detalle cómo GitHub Actions construye el `subject claim` del token OIDC, se identificó que el formato cambia cuando un job declara explícitamente un `environment:` en el workflow. En ese caso, el subject ya no sigue el patrón `ref:refs/heads/main` ni `pull_request` — pasa a tener la forma `environment:<nombre>`, sin importar si el evento que disparó el workflow fue un `push` o un `pull_request`.

Esto explica por qué el primer intento fallaba: ningún job real del pipeline generaba esos dos subjects exactos. Los jobs `terraform-plan-dev`, `terraform-plan-staging`, `terraform-apply-dev` y `terraform-apply-staging` declaran `environment: dev` o `environment: staging` (necesario para poder leer los Environment Secrets `DEV_DB_PASSWORD` y `STAGING_DB_PASSWORD`), por lo que su subject real es `environment:dev` o `environment:staging`. Solo el job `validate` (que no usa `environment:`) genera el subject `pull_request` tal como se esperaba originalmente.

La condición final, sin wildcard, quedó así:

```
repo:<org>/<repo>:environment:dev
repo:<org>/<repo>:environment:staging
repo:<org>/<repo>:pull_request
```

Esto restringe el rol exclusivamente a los jobs reales del pipeline, sin necesidad de un patrón genérico a nivel de repositorio completo. Se verificó la configuración aplicada directamente en AWS con `aws iam get-role`, y se confirmó el funcionamiento corriendo el pipeline completo (`fmt`, `validate`, `terraform-plan-dev`, `terraform-plan-staging`) de punta a punta sin errores de autorización.

### Eliminación de credenciales estáticas

Después de confirmar que los workflows ya autenticaban correctamente usando OIDC, se eliminaron las credenciales estáticas de GitHub Secrets:
* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`

Los workflows que ya funcionan con OIDC son:

* `terraform-ci.yml`
* `terraform-destroy.yml`
* `terraform-drift.yml`

Estos workflows utilizan: `aws-actions/configure-aws-credentials@v4` junto con el parámetro: `role-to-assume`.

La evidencia de esta eliminación se encuentra en: `infra/evidence/oidc-secrets-removed.png`

---

## 4. Diseño de Observability

Para monitorear el comportamiento del sistema, se definieron alarmas y métricas principales en AWS CloudWatch.

### Alarmas definidas

| Alarma              | Threshold                                                                  | Justificación                                                                                                                                                                                                 |
| ------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lambda-api-errors` | 5 o más errores en 300 segundos                                            | Un error aislado puede ser algo temporal, por ejemplo un timeout puntual con RDS. Sin embargo, 5 errores en 5 minutos indican un problema más serio que puede estar afectando a los usuarios.                 |
| `sqs-queue-depth`   | 50 o más mensajes visibles durante 2 períodos consecutivos de 300 segundos | Un aumento breve en la cola puede ser normal cuando hay carga. Pero si la cola se mantiene alta durante 10 minutos, significa que Lambda Worker no está procesando los trabajos al mismo ritmo en que llegan. |

### Widgets seleccionados para el dashboard

El dashboard incluye tres métricas principales:

1. **Request count — API Gateway**
   Esta métrica permite ver cuántas solicitudes está recibiendo la aplicación.

2. **Error rate — Lambda API**
   Esta métrica muestra si el servicio principal está fallandole al usuario.

3. **Queue depth — SQS**
   Esta métrica permite identificar si los trabajos se están acumulando en la cola. Una cola alta puede indicar que los reportes están tardando más tiempo en generarse.

### Presupuesto

Se configuró un presupuesto mensual de: `$20 USD`.
También se configuró una notificación cuando el consumo alcance el 80% del presupuesto, es decir:`$16 USD`.
La notificación se envía al mismo SNS topic utilizado por las alarmas: `oyd-project-dev-alerts`
Esto permite centralizar las alertas operativas y de presupuesto en un solo canal.

---

## 5. Dos trade-offs arquitectónicos

### Trade-off 1 — Usar CloudFront para redirigir HTTP a HTTPS

API Gateway HTTP API no permite escuchar directamente en el puerto 80. Por esta razón, cuando se intenta acceder por HTTP, el servicio no puede responder con una redirección normal hacia HTTPS. La guía del proyecto pedía que el redirect de HTTP a HTTPS fuera verificable con `curl`, y no simplemente que el puerto 80 estuviera cerrado. Para cumplir con este requisito, se decidió agregar CloudFront delante de API Gateway. CloudFront fue configurado con: `viewer_protocol_policy = "redirect-to-https"`.Esto permite que las solicitudes HTTP sean redirigidas automáticamente hacia HTTPS con una respuesta 301.
#### Ventaja

La principal ventaja es que el sistema ofrece un comportamiento más seguro y controlado para el usuario. En lugar de rechazar la conexión HTTP o dejar el puerto sin respuesta, CloudFront redirige automáticamente la solicitud hacia HTTPS. Esto garantiza que el tráfico termine usando una conexión cifrada, mejora la experiencia del usuario y permite comprobar el comportamiento esperado mediante herramientas como curl. Además, esta solución deja el cumplimiento del requisito en una capa administrada por AWS, sin tener que modificar la lógica interna de la aplicación ni agregar código adicional en las funciones Lambda.

#### Desventaja

La desventaja es que se agrega un componente adicional a la arquitectura. Esto implica mayor complejidad en la infraestructura, ya que CloudFront requiere configuración propia y un certificado ACM en la región us-east-1. También puede existir una pequeña latencia adicional debido a que la solicitud pasa primero por CloudFront antes de llegar a API Gateway. Aun así, se consideró que el beneficio de tener una redirección HTTP a HTTPS segura, verificable y administrada por AWS justificaba la complejidad adicional.

---
### Trade-off 2 — Usar una única Hosted Zone para varios ambientes

El dominio delegado por el curso fue: `grupo1.oyd.solid.com.gt`.

Este dominio solo puede delegarse una vez hacia un único conjunto de name servers. Por esta razón, no era conveniente crear una Hosted Zone independiente para cada ambiente. Inicialmente, el diseño creaba una `aws_route53_zone` tanto en dev como en staging. Esto generó un problema: la zona de staging quedaba creada en AWS, pero sus name servers no estaban realmente delegados. Como resultado, staging tenía una zona DNS huérfana y la validación DNS del certificado ACM fallaba.
Para resolverlo, se agregaron dos variables:

- `create_dns_zone`
- `hosted_zone_id`

Con este cambio, únicamente el ambiente dev crea la Hosted Zone real en Route53. El ambiente staging reutiliza esa misma zona mediante el `hosted_zone_id`.

#### Ventaja

La principal ventaja es que se mantiene una única fuente de verdad para la administración DNS del dominio. Esto evita crear zonas duplicadas que no están delegadas y reduce el riesgo de errores al validar certificados ACM o crear registros DNS. Además, esta solución hace que ambos ambientes trabajen sobre el dominio correctamente delegado. De esta forma, dev y staging pueden crear sus registros dentro de la misma zona válida, evitando inconsistencias entre lo que existe en AWS y lo que realmente resuelve en DNS público. También mejora la estabilidad del despliegue, porque la validación de certificados y la creación de registros dependen de una zona que sí está activa y correctamente delegada.

#### Desventaja

La desventaja es que los ambientes ya no quedan completamente independientes. Dev administra un recurso compartido que staging necesita reutilizar. Esto introduce una pequeña asimetría entre los archivos de configuración, porque `staging.tfvars` no puede copiar exactamente el mismo patrón de `dev.tfvars`. En staging se debe indicar explícitamente el `hosted_zone_id` de la zona creada en dev. Aun así, se consideró que reutilizar una única Hosted Zone era la mejor decisión, porque evita errores de DNS, elimina zonas huérfanas y permite que la validación de certificados funcione correctamente en ambos ambientes.

---