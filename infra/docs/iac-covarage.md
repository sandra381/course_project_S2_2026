# Auditoría de Cobertura de IaC

| Componente de la Aplicación | Servicio de Nube Usado | Tipo de Recurso Terraform | Ruta del Módulo |
|---|---|---|---|
| Red virtual (VPC, subnets, gateways) | Amazon VPC | `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_nat_gateway`, `aws_eip`, `aws_route_table`, `aws_route_table_association` | `infra/modules/network/main.tf` |
| Listas de control de acceso de red | Amazon VPC | `aws_network_acl` (public, private) | `infra/modules/network/main.tf` |
| Grupos de seguridad | Amazon VPC | `aws_security_group` (app_sg, db_sg, web_sg), `aws_security_group_rule` | `infra/modules/network/main.tf` |
| API Gateway (ingreso HTTP) | Amazon API Gateway v2 | `aws_apigatewayv2_api`, `aws_apigatewayv2_integration`, `aws_apigatewayv2_route` (get, post, root), `aws_apigatewayv2_stage`, `aws_lambda_permission.api_gw` | `infra/modules/ingress/main.tf` |
| Lambda API (handler principal) | AWS Lambda | `aws_lambda_function.api` | `infra/modules/compute/main.tf` |
| Lambda Worker (procesamiento async) | AWS Lambda | `aws_lambda_function.worker`, `aws_lambda_event_source_mapping.sqs_worker` | `infra/modules/compute/main.tf` |
| Lambda Layers (dependencias Python) | AWS Lambda | `aws_lambda_layer_version` (pymysql, reportlab) | `infra/modules/compute/main.tf` |
| Lambda Cleanup (jobs huérfanos) | AWS Lambda | `aws_lambda_function.cleanup` | `infra/modules/scheduler/main.tf` |
| Tarea programada de limpieza | Amazon EventBridge Scheduler | `aws_scheduler_schedule.cleanup` | `infra/modules/scheduler/main.tf` |
| Base de datos relacional | Amazon RDS (MySQL) | `aws_db_instance.this`, `aws_db_subnet_group.this`, `aws_db_parameter_group.this` | `infra/modules/database/main.tf` |
| Bucket de archivos CSV | Amazon S3 | `aws_s3_bucket.this` + versioning, encryption, lifecycle, CORS, policy, public access block | `infra/modules/storage/main.tf` (instancia `storage_files`) |
| Bucket de reportes PDF | Amazon S3 | `aws_s3_bucket.this` + versioning, encryption, lifecycle, CORS, policy, public access block | `infra/modules/storage/main.tf` (instancia `storage_reports`) |
| Bucket de assets de la app | Amazon S3 | `aws_s3_bucket.app_assets`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration` | `infra/main.tf` |
| Cola principal de trabajos | Amazon SQS | `aws_sqs_queue.main` | `infra/modules/async/main.tf` |
| Dead Letter Queue | Amazon SQS | `aws_sqs_queue.dlq` | `infra/modules/async/main.tf` |
| Role: Lambda API | AWS IAM | `aws_iam_role.lambda_api`, `aws_iam_role_policy.lambda_api_logs/rds/s3/sqs`, `aws_iam_role_policy_attachment.lambda_api_vpc` | `infra/modules/iam/main.tf` |
| Role: Lambda Worker | AWS IAM | `aws_iam_role.lambda_worker`, `aws_iam_role_policy.lambda_worker_logs/s3/sqs`, `aws_iam_role_policy_attachment.lambda_worker_vpc` | `infra/modules/iam/main.tf` |
| Role: Lambda Cleanup | AWS IAM | `aws_iam_role.lambda_cleanup`, `aws_iam_role_policy.lambda_cleanup_logs`, `aws_iam_role_policy_attachment.lambda_cleanup_vpc` | `infra/modules/iam/main.tf` |
| Role: EventBridge Scheduler | AWS IAM | `aws_iam_role.scheduler_exec`, `aws_iam_role_policy.scheduler_invoke` | `infra/modules/iam/main.tf`, `infra/modules/scheduler/main.tf` |
| Role: CI Runner (GitHub Actions) + OIDC | AWS IAM | `aws_iam_role.ci_runner`, `aws_iam_openid_connect_provider.github`, 10 policies (`ci_runner_apigw/dns_tls_observability/ec2/iam/lambda/observability/rds/s3_app/scheduler/secrets_kms/sqs/state`), `aws_iam_role_policy_attachment.ci_runner_readonly` | `infra/modules/iam/main.tf` |
| Llave de encriptación (CMK) | AWS KMS | `aws_kms_key.main`, `aws_kms_alias.main` | `infra/modules/secrets/main.tf` |
| Secret de contraseña de RDS | AWS Secrets Manager | `aws_secretsmanager_secret.db_password`, `aws_secretsmanager_secret_version.db_password`, `aws_iam_role_policy.lambda_api/worker/cleanup_secrets` | `infra/modules/secrets/main.tf` |
| Log groups de las 3 Lambdas | Amazon CloudWatch Logs | `aws_cloudwatch_log_group.lambda["api"]`, `["worker"]`, `["cleanup"]` | `infra/modules/observability/main.tf` |
| Alarma: errores de Lambda API | Amazon CloudWatch Alarms | `aws_cloudwatch_metric_alarm.lambda_api_errors` | `infra/modules/observability/main.tf` |
| Alarma: profundidad de cola SQS | Amazon CloudWatch Alarms | `aws_cloudwatch_metric_alarm.sqs_queue_depth` | `infra/modules/observability/main.tf` |
| Dashboard de observabilidad | Amazon CloudWatch Dashboards | `aws_cloudwatch_dashboard.main` | `infra/modules/observability/main.tf` |
| Tópico y suscripción de alertas | Amazon SNS | `aws_sns_topic.alerts`, `aws_sns_topic_subscription.alerts_email` | `infra/modules/observability/main.tf` |
| Presupuesto mensual | AWS Budgets | `aws_budgets_budget.monthly` | `infra/modules/observability/main.tf` |
| Certificado SSL del dominio | AWS Certificate Manager | `aws_acm_certificate.api`, `aws_acm_certificate_validation.api` | `infra/acm.tf` |
| Distribución CDN (redirect HTTP→HTTPS) | Amazon CloudFront | `aws_cloudfront_distribution.api` | `infra/cloudfront.tf` |
| Registro DNS del dominio público | Amazon Route 53 | `aws_route53_record.api` | `infra/custom-domain.tf` |
| Registro DNS de validación del certificado | Amazon Route 53 | `aws_route53_record.cert_validation["api.grupo1.oyd.solid.com.gt"]` | `infra/acm.tf` |
| Zona DNS delegada | Amazon Route 53 | Reutilizada vía `hosted_zone_id` (no creada en este ambiente) | `infra/dns.tf` |

---

## Confirmación de no creación manual

El equipo confirma que ningún recurso de este proyecto fue creado manualmente a través de la consola de AWS en ningún momento durante las Deliveries 1 a 5. Cada recurso listado en la tabla anterior está confirmado en `infra/evidence/state-list.txt` (salida completa de `terraform state list` del ambiente `dev`), y fue provisionado exclusivamente mediante `terraform apply` — ejecutado localmente durante el desarrollo o automáticamente por el pipeline de GitHub Actions (`.github/workflows/terraform-ci.yml`). No se realizó ningún `terraform import` sobre un recurso creado manualmente durante esta entrega.

## Cobertura por categoría requerida

| Categoría | Recursos confirmados en el state list real |
|---|---|
| Compute | `module.compute.aws_lambda_function.api`, `.worker`; `module.scheduler.aws_lambda_function.cleanup`; layers `pymysql`, `reportlab` |
| Storage | `module.storage_files.aws_s3_bucket.this`, `module.storage_reports.aws_s3_bucket.this`, `aws_s3_bucket.app_assets` |
| Database | `module.database.aws_db_instance.this` |
| Networking | `module.network.aws_vpc.this`, `aws_subnet.public/private`, `aws_nat_gateway.this[0]`, `aws_internet_gateway.this` |
| Async | `module.async.aws_sqs_queue.main`, `.dlq` |
| Security/IAM | `module.iam.aws_iam_role.ci_runner`, `.lambda_api`, `.lambda_worker`, `.lambda_cleanup`, `.scheduler_exec`; `module.iam.aws_iam_openid_connect_provider.github[0]`; `module.secrets.aws_kms_key.main` |
| Observability | `module.observability.aws_cloudwatch_log_group.lambda[*]`, `.aws_cloudwatch_metric_alarm.lambda_api_errors`, `.sqs_queue_depth`, `.aws_cloudwatch_dashboard.main`, `.aws_sns_topic.alerts`, `.aws_budgets_budget.monthly` |

Ningún recurso visible en la consola de AWS queda fuera de `infra/evidence/state-list.txt`.

## Notas

- Todos los recursos son provisionados por Terraform y rastreados en un state remoto (backend S3 con bloqueo vía DynamoDB, configurado en `infra/bootstrap/`).
- La zona hospedada de Route 53 (`grupo1.oyd.solid.com.gt`) fue delegada por el instructor del curso. El ambiente `dev` la administra como recurso compartido vía `create_dns_zone = true`; el ambiente `staging` la reutiliza por referencia (`hosted_zone_id`) en vez de crear una duplicada — un dominio delegado no puede existir dos veces bajo una misma cuenta de AWS.
- El OIDC Provider y el CI Runner Role (`infra/modules/iam/main.tf`) tienen `lifecycle { prevent_destroy = true }` para garantizar que el pipeline de CI/CD mantenga la capacidad de re-autenticarse después de un ciclo completo de destrucción/recreación del ambiente.
- El pipeline de CI/CD (`.github/workflows/terraform-ci.yml`) ejecuta `fmt`, `validate` y `plan` en cada PR tanto para `dev` como para `staging`, y `apply` automáticamente al hacer merge a `main`.
- La prueba de destroy + reapply (clean-state, one-click deployment) fue verificada exitosamente durante el desarrollo de este delivery — `ver evidencia en infra/evidence/clean-state-pipeline.png` y los runs correspondientes de GitHub Actions.