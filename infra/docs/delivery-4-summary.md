# Delivery 4 — Async Infrastructure & Full CD Pipeline

**Proyecto:** SPVR (Sistema de Procesamiento y Validación de Reportes)
**Curso:** Optimización y Desempeño
**Equipo:** Gaby, Diego Sican, Sandra Soria
**Repositorio:** sandra381/course_project_S2_2026
**Cuenta AWS:** 121218949493 (us-east-1)

---

## 1. Diseño de mensajería asíncrona

Usamos SQS standard, no FIFO, para la cola principal `spvr-jobs-queue`. La razón es simple: a SPVR no le importa el orden en que se procesan los reportes de distintos usuarios — el reporte del usuario A no depende del reporte del usuario B. Como no necesitábamos esa garantía de orden, no tenía sentido pagar el costo de FIFO (menos throughput y la complejidad de manejar `MessageGroupId`).

El DLQ está configurado con `max_receive_count = 3`, es decir, un mensaje se reintenta hasta 3 veces antes de moverse a la cola `spvr-jobs-dlq`. Llegamos a ese número pensando en los fallos que realmente nos pasaron durante las pruebas: la mayoría de errores (RDS tardando en responder, un timeout generando el PDF) se resuelven en el segundo o tercer intento. Con 1 intento hubiéramos descartado mensajes que en realidad sí podían procesarse bien si se reintentaban; con más de 5 hubiéramos tardado mucho en darnos cuenta de que un mensaje tenía un error real de código y no solo mala suerte.

La retención de mensajes (`message_retention_seconds`) es de 86400 segundos (1 día) en dev y 259200 segundos (3 días) en staging. En dev no se necesita retención larga porque los mensajes se prueban y se descartan rápido; en staging se buscó dejar más margen para inspeccionar mensajes fallidos antes de que expiren, ya que staging es el ambiente donde se valida el comportamiento antes de pasar a producción. El DLQ retiene mensajes por `1209600` segundos (14 días, el máximo permitido por SQS) en ambos ambientes, para no perder evidencia de fallos mientras el equipo investiga la causa.

No se requirió ordenamiento FIFO porque cada job de SPVR tiene un `job_id` único e independiente; dos reportes pueden generarse en cualquier orden sin afectar la integridad de los datos en RDS ni en S3.

---

## 2. Arquitectura orientada a eventos

El compute target (Lambda Worker, definido en D2/D3) se dispara mediante un `aws_lambda_event_source_mapping` que conecta la cola SQS directamente con la función `oyd-project-<env>-worker`.

En dev, el `batch_size` es `3` con `maximum_batching_window_in_seconds = 0`: el Worker procesa hasta 3 mensajes por invocación sin esperar a que se acumule un batch más grande, dando un balance entre no disparar una invocación por cada mensaje individual y mantener tiempos de respuesta rápidos durante desarrollo. En staging, el `batch_size` sube a `5` con una ventana de batching de `30` segundos, simulando una carga más realista donde varios CSV pueden estar en cola al mismo tiempo.

Inicialmente declaramos `bisect_batch_on_function_error` como variable en ambos ambientes, pensando en usarla para aislar mensajes problemáticos dividiendo el batch en mitades sucesivas. Investigando encontramos que este parámetro solo es compatible con fuentes de tipo stream (Kinesis, DynamoDB Streams, Amazon MSK) y nunca estuvo soportado para event source mappings de SQS, sin importar el tamaño del batch. Por eso el recurso final en `modules/compute/main.tf` no incluye ese atributo en ninguno de los dos ambientes, aunque la variable sigue declarada por completitud. Para manejo de errores en SQS, contamos en su lugar con el `redrive_policy` del DLQ, que cumple la función de aislar mensajes problemáticos sin necesitar bisect.

Cuando un mensaje agota sus 3 intentos, SQS lo manda automáticamente al DLQ `spvr-jobs-dlq` gracias al `redrive_policy` que configuramos en el módulo `async`. Cuando esto pasa, revisamos manualmente qué hay en el DLQ con `aws sqs receive-message` para entender qué salió mal (normalmente es un CSV con datos raros o que RDS tardó demasiado en responder) y decidimos si vale la pena reprocesar ese mensaje a mano o simplemente descartarlo.

---

## 3. Layout de entornos Terraform y pipeline de CD

La estructura de entornos sigue Pattern A — backends separados: cada ambiente tiene su propio archivo `infra/envs/<env>/backend-<env>.hcl` (`backend-dev.hcl` y `backend-staging.hcl`), pasado explícitamente a `terraform init -backend-config=...` en cada paso del workflow de CI/CD. Se eligió este patrón sobre Terraform workspaces porque ofrece mayor explicitud: cada ambiente tiene un state file completamente separado en S3 con su propio key, lo que reduce el riesgo de que un comando ejecutado en el ambiente equivocado afecte el state de otro ambiente — un riesgo real cuando se trabaja en equipo con múltiples personas ejecutando comandos desde distintas máquinas.

Tres valores de variable difieren entre `dev.tfvars` y `staging.tfvars`:

1. **`vpc_cidr` y los CIDRs de subred** — dev usa `10.0.0.0/16`, staging usa `10.1.0.0/16`. Esto permite que ambos ambientes coexistan simultáneamente en la misma cuenta AWS sin conflicto de rangos de red.
2. **`message_retention_seconds`** — 86400 (1 día) en dev contra 259200 (3 días) en staging, reflejando que staging necesita más tiempo de inspección antes de promover cambios a producción.
3. **`batch_size` y `maximum_batching_window_in_seconds`** — 3/0 en dev contra 5/30 en staging, para simular en staging una carga de mensajes más cercana a producción.

El flujo de promoción en `terraform-ci.yml` funciona así: cada vez que se abre un Pull Request, el job de plan genera dos planes por separado — uno para dev y otro para staging — y sube cada uno como artifact independiente (`tfplan-dev` y `tfplan-staging`). El plan combinado se comenta automáticamente en el PR para que cualquiera lo pueda revisar antes de aprobar. Cuando se hace merge a `main`, el apply de dev corre solo, sin pedir aprobación, descarga el `tfplan-dev` que ya se generó en el PR y lo aplica directamente — no vuelve a correr `plan`. Una vez que dev termina bien, el apply de staging queda listo pero se detiene esperando que alguien lo apruebe desde GitHub, porque ese ambiente tiene un reviewer obligatorio configurado. Los tres del equipo (Gaby, Diego y Sandra) podemos aprobar ese paso. Después de la aprobación, baja el `tfplan-staging` y lo aplica, también sin re-planear.

Los secretos están namespaced por ambiente: `DEV_DB_PASSWORD` vive en los Environment Secrets de `dev`, y `STAGING_DB_PASSWORD` vive en los Environment Secrets de `staging` — ninguno se almacena como secreto de repositorio, evitando que ambos ambientes compartan la misma credencial.

El ruleset que configuramos en `main` (estado Active) exige que pasen los tres checks Terraform Format Check, Terraform Validate y Terraform Plan antes de poder mergear, además de pedir que la rama esté al día con `main` y bloquear force-push y borrado de la rama. Las dos últimas reglas se complementan: pedir que la rama esté actualizada evita que alguien mergee un PR viejo sin que los checks hayan corrido de nuevo contra los cambios más recientes de `main`, y bloquear force-push evita que alguien sobreescriba el historial de `main` directamente sin pasar por todo ese flujo de PR y revisión.

---

## 4. Trabajos programados

La función programada se llama `oyd-project-dev-cleanup` y hace limpieza de jobs antiguos (`cleanup-stale-jobs`): revisa la tabla de jobs en RDS y marca como expirados los que llevan más de `stale_hours` (2 horas) atascados en `PENDIENTE` o `PROCESANDO` sin completarse. Esto evita que jobs que fallaron silenciosamente (por ejemplo, si el Worker se cayó a medio procesar) se queden ocupando espacio para siempre sin que nadie se entere.

El `aws_scheduler_schedule` corre con `rate(1 hour)`, es decir, cada hora. Elegimos esa frecuencia porque un job normal de SPVR tarda segundos en completarse, así que si después de 2 horas sigue sin terminar, casi seguro algo falló. Revisarlo cada hora nos da tiempo suficiente de reacción sin meterle carga innecesaria a RDS con revisiones más seguidas. La zona horaria es `America/Guatemala`, donde está el equipo.

El rol IAM del scheduler (`oyd-project-dev-scheduler-role`) solo tiene `lambda:InvokeFunction` apuntando al ARN exacto de `oyd-project-dev-cleanup` — nada de `Resource: "*"`. Es un rol mucho más limitado que el del Worker o la API, y eso es intencional: el scheduler solo necesita poder disparar esa una función puntual, no necesita tocar SQS, S3 ni RDS directamente como sí lo necesita el rol de ejecución del Worker.

---

## 5. Prueba end-to-end del flujo asíncrono

Usamos Python 3.12 en AWS Lambda, el mismo runtime que venimos usando desde Infraestructura en la Nube y D3.

El flujo completo va así: el endpoint `POST /jobs/enqueue` del Lambda API recibe el `job_id` y el `id_usuario`, revisa que el job exista y que no esté ya completado en RDS, y manda el mensaje a la cola `spvr-jobs-queue` con `sqs.send_message()`. La API responde con HTTP 202 y el `message_id` real que devuelve SQS. El event source mapping que armamos en el Deliverable B detecta ese mensaje nuevo y dispara el Lambda Worker automáticamente. El Worker toma el `job_id`, baja el CSV correspondiente del bucket `oyd-project-dev-files` (que se subió antes vía presigned URL desde `/upload`), lo procesa con pandas, genera el PDF con reportlab, y lo guarda en el bucket `oyd-project-dev-reports` con `s3.put_object()`. Al final actualiza el estado del job en RDS a `COMPLETADO`.

El rol de ejecución del Worker (`oyd-project-dev-lambda-role`) está limitado a recursos específicos, sin wildcards: `sqs:ReceiveMessage`, `sqs:DeleteMessage` y `sqs:GetQueueAttributes` solo sobre el ARN exacto `arn:aws:sqs:us-east-1:121218949493:spvr-jobs-queue`, y `s3:PutObject` solo sobre `arn:aws:s3:::oyd-project-dev-reports/*` para guardar los reportes, más `s3:GetObject`/`s3:PutObject` sobre `arn:aws:s3:::oyd-project-dev-files/*` para leer los CSV subidos. Este último permiso de PutObject sobre el bucket de reportes nos costó un rato de debugging — al principio no lo teníamos y el Worker fallaba con `AccessDenied` al intentar guardar el PDF, así que tuvimos que agregarlo explícitamente al IAM policy.

El nombre del archivo PDF en S3 se forma con el `job_id` y un timestamp del momento en que se procesó, así: `reports/reporte_<job_id>_<timestamp>.pdf` (por ejemplo, `reports/reporte_3_20260617180530.pdf`). Esto evita que dos reportes se sobreescriban entre sí y de paso permite saber a qué job pertenece cada archivo solo viendo el nombre, sin tener que ir a consultar RDS.

---

## 6. Dos decisiones arquitectónicas con justificación

**Decisión 1 — SQS standard contra SQS FIFO.** 
Optamos por standard porque a SPVR no le importa el orden entre jobs de distintos usuarios; cada reporte es independiente. Si hubiéramos usado FIFO, habríamos limitado el throughput (300 mensajes por segundo sin batching, contra básicamente sin límite en standard) y tendríamos que manejar `MessageGroupId` y `MessageDeduplicationId` sin que nuestro caso de uso realmente lo necesitara. La contra de standard es que, en teoría, un mensaje podría procesarse dos veces o fuera de orden. Eso no nos preocupa mucho porque el Worker ya revisa en RDS si el job está `COMPLETADO` o `FALLIDO` antes de reprocesarlo — esa verificación nos da la idempotencia que necesitamos sin pagar el costo de FIFO.

**Decisión 2 — Backends separados (Pattern A) contra Terraform workspaces (Pattern B).** Elegimos backends separados porque dan mayor explicitud sobre cuál ambiente se está afectando en cada momento. Con Terraform workspaces, el ambiente activo depende de un comando previo (`terraform workspace select <env>`) que es fácil de olvidar, y si se olvida, Terraform no avisa nada — simplemente aplica los cambios contra el workspace que haya quedado seleccionado, que podría no ser el correcto. Con backends separados, cada `terraform init -backend-config=...` deja explícito en el comando mismo contra qué ambiente se está trabajando, y si alguien usa el archivo de backend equivocado, Terraform tira un error de inicialización al instante en vez de aplicar cambios silenciosamente donde no debía. El costo es mantener dos archivos `.hcl` en vez de uno, pero con solo dos ambientes (dev y staging) y archivos tan pequeños, no nos pareció un costo real frente a la seguridad que da la explicitud.