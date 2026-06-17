variable "environment" {
  description = "Deployment environment. Controls naming, tagging, and resource sizing. Valid values: dev, prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either 'dev' or 'prod'."
  }
}

variable "project_name" {
  description = "Name of the project. Used as a prefix for all resource names to avoid collisions across accounts."
  type        = string
  default     = "oyd-project"
}

variable "region" {
  description = "AWS region where all resources will be provisioned (e.g., us-east-1, us-west-2)."
  type        = string
  default     = "us-east-1"
}

variable "app_bucket_prefix" {
  description = "Prefix for the S3 bucket name. The environment is appended automatically."
  type        = string
  default     = "app-assets"
}

variable "db_username" {
  description = "Master username for the RDS database instance."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the RDS database instance. Never commit this value."
  type        = string
  sensitive   = true
}

# ─── VARIABLES DE RED  ─────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. One per availability zone."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. One per availability zone."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones to deploy subnets into."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "single_nat_gateway" {
  description = "If true, a single NAT Gateway is used for all private subnets. If false, one per AZ."
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Path used for health checks on the API Gateway."
  type        = string
  default     = "/"
}

# ─── VARIABLES ASYNC  ─────────────────────────────────────────────────────

variable "queue_name_prefix" {
  description = "Prefijo para las colas SQS. Genera queue_name_prefix-queue y queue_name_prefix-dlq."
  type        = string
  default     = "spvr-jobs"
}

variable "visibility_timeout_seconds" {
  description = "Segundos que un mensaje es invisible mientras Lambda Worker lo procesa. Igual a 60s según decisión del documento E4 de Infra."
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "Segundos que la cola principal retiene mensajes no procesados. 86400 = 1 día."
  type        = number
  default     = 86400
}

variable "max_receive_count" {
  description = "Reintentos máximos antes de mover un mensaje a la DLQ. 3 según decisión del documento E4 de Infra."
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "Segundos que la DLQ retiene mensajes fallidos. 1209600 = 14 días para que el administrador los inspeccione."
  type        = number
  default     = 1209600
}

# ─── VARIABLES EVENT SOURCE MAPPING ──────────────────────────────────────
variable "batch_size" {
  description = "Mensajes que Lambda Worker procesa por invocación desde SQS."
  type        = number
  default     = 1
}

variable "maximum_batching_window_in_seconds" {
  description = "Segundos que AWS espera para acumular mensajes antes de invocar Lambda Worker."
  type        = number
  default     = 0
}

variable "bisect_batch_on_function_error" {
  description = "Si Lambda Worker falla, divide el batch a la mitad para aislar el mensaje problemático."
  type        = bool
  default     = true
}

# ─── VARIABLES SCHEDULER  ─────────────────────────────────────────────────

variable "schedule_expression" {
  description = "Expresión de horario para EventBridge Scheduler. rate(1 hour) ejecuta Lambda Cleanup cada hora."
  type        = string
  default     = "rate(1 hour)"
}

variable "scheduler_timezone" {
  description = "Zona horaria para la expresión cron del scheduler."
  type        = string
  default     = "America/Guatemala"
}

variable "stale_hours" {
  description = "Horas máximas que un job puede estar en PENDIENTE o PROCESANDO antes de marcarse FALLIDO."
  type        = number
  default     = 2
}
