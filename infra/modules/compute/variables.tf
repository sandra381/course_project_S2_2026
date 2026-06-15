variable "environment" {
  description = "Deployment environment (dev or prod)."
  type        = string
}

variable "name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "memory_size" {
  description = "Amount of memory in MB allocated to the Lambda function."
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Timeout in seconds for the Lambda function execution."
  type        = number
  default     = 30
}

variable "project_name" {
  description = "Name of the project, used as prefix in resource names."
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket that the Lambda function is allowed to read from and write to."
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket used by the Lambda function."
  type        = string
}

variable "db_host" {
  description = "Endpoint of the RDS instance the Lambda function will connect to."
  type        = string
}

variable "db_name" {
  description = "Name of the MySQL database the Lambda function will use."
  type        = string
}

variable "db_username" {
  description = "Username to connect to the RDS instance."
  type        = string
}

variable "db_password" {
  description = "Password to connect to the RDS instance. Must not appear in any committed file."
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "List of private subnet IDs where the Lambda function will run."
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the Lambda function."
  type        = list(string)
}

variable "sqs_queue_arn" {
  description = "ARN de la cola SQS principal. Se usa en la política IAM y en el event source mapping para conectar la cola con Lambda Worker."
  type        = string
}

variable "batch_size" {
  description = "Número de mensajes que Lambda Worker procesa por invocación. Con 1 se procesa un CSV a la vez, lo que facilita el diagnóstico de errores."
  type        = number
  default     = 1
}

variable "maximum_batching_window_in_seconds" {
  description = "Segundos que AWS espera para acumular mensajes antes de invocar Lambda Worker, aunque el batch no esté lleno."
  type        = number
  default     = 0
}

variable "bisect_batch_on_function_error" {
  description = "Si Lambda Worker falla, divide el batch a la mitad para aislar qué mensaje específico causó el error. Recomendado true para facilitar debugging."
  type        = bool
  default     = true
}

variable "s3_reports_bucket_name" {
  description = "Nombre del bucket S3 donde Lambda Worker guarda los reportes PDF generados."
  type        = string
}

variable "sqs_queue_url" {
  description = "URL de la cola SQS principal. Se inyecta como variable de entorno en Lambda Worker."
  type        = string
}
