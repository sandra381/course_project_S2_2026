variable "project_name" {
  description = "Nombre del proyecto. Se usa como prefijo en los recursos del scheduler."
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging). Controla el naming de los recursos."
  type        = string
}

variable "schedule_expression" {
  description = "Expresión de horario para EventBridge Scheduler. Formato rate o cron. Ejemplo: rate(1 hour) o cron(0 * * * ? *)."
  type        = string
}

variable "scheduler_timezone" {
  description = "Zona horaria para interpretar la expresión cron del scheduler. Ejemplo: America/Guatemala."
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnet IDs privadas donde corre Lambda Cleanup dentro de la VPC."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Lista de security group IDs que se adjuntan a Lambda Cleanup."
  type        = list(string)
}

variable "db_host" {
  description = "Endpoint de la instancia RDS a la que Lambda Cleanup se conecta para actualizar estados."
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos MySQL del proyecto."
  type        = string
}

variable "db_username" {
  description = "Usuario para conectarse a RDS."
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret storing the DB password. Injected as DB_SECRET_ARN env var. Provided by module.secrets.secret_arn."
  type        = string
}

variable "stale_hours" {
  description = "Horas que puede estar un job en PENDIENTE o PROCESANDO antes de marcarse como FALLIDO automáticamente."
  type        = number
  default     = 2
}

variable "pymysql_layer_arn" {
  description = "ARN del Lambda Layer de pymysql creado en el módulo compute. Se reutiliza para no duplicar el layer."
  type        = string
}

variable "cleanup_role_arn" {
  description = "ARN of the Lambda Cleanup execution role. Provided by module.iam.lambda_cleanup_role_arn."
  type        = string
}

variable "scheduler_role_arn" {
  description = "ARN of the EventBridge Scheduler role. Provided by module.iam.scheduler_exec_role_arn. Used in the schedule target."
  type        = string
}

variable "scheduler_role_id" {
  description = "ID (name) of the EventBridge Scheduler role. Provided by module.iam.scheduler_exec_role_id. Used to attach the invoke policy in this module."
  type        = string
}