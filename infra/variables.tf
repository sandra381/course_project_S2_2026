variable "environment" {
  description = "Deployment environment. Controls naming, tagging, and resource sizing. Valid values: dev, prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be either 'dev', 'staging', or 'prod'."
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

variable "github_org" {
  description = "GitHub organization or username that owns the repository. Used to scope the OIDC trust policy to a specific repository."
  type        = string
  default     = "sandra381"
}

variable "github_repo" {
  description = "GitHub repository name. Used in the OIDC trust policy condition: repo:<org>/<repo>:ref:refs/heads/main."
  type        = string
  default     = "course_project_S2_2026"
}

variable "tf_state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform remote state (created in infra/bootstrap/). Required by the CI runner IAM policy."
  type        = string
  default     = "oyd-project-terraform-state-2026"
}

variable "tf_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking (created in infra/bootstrap/). Required by the CI runner IAM policy."
  type        = string
  default     = "oyd-project-terraform-locks-2026"
}

variable "create_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider. Should be true only in dev (default), since the provider is account-wide and shared."
  type        = bool
  default     = true
}

variable "api_domain_name" {
  description = "Custom domain name for the public API, served via CloudFront with a valid ACM certificate."
  type        = string
}

variable "root_domain_name" {
  description = "Delegated root domain managed in Route 53."
  type        = string
  default     = "grupo1.oyd.solid.com.gt"
}

variable "create_dns_zone" {
  description = "Whether this environment should create the Route 53 hosted zone. Only one environment should create it."
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone ID to reuse when create_dns_zone is false."
  type        = string
  default     = null
}

variable "ssl_policy_name" {
  description = "Minimum TLS protocol version enforced by CloudFront for HTTPS connections."
  type        = string
  default     = "TLSv1.2_2021"
}

variable "redirect_http_to_https" {
  description = "CloudFront viewer protocol policy. 'redirect-to-https' enforces HTTP 301 redirect to HTTPS as required by Deliverable D."
  type        = string
  default     = "redirect-to-https"
}

# Observability variables
variable "log_retention_days" {
  description = "Number of days CloudWatch Logs retains log events before automatic expiration."
  type        = number
  default     = 14
}

variable "alarm_notification_email" {
  description = "Email address that receives SNS notifications when an alarm or budget threshold triggers."
  type        = string
}

variable "lambda_error_threshold" {
  description = "Number of Lambda errors within the evaluation period that triggers the error-rate alarm."
  type        = number
  default     = 5
}

variable "lambda_error_evaluation_periods" {
  description = "Number of consecutive periods the error threshold must be breached before the alarm fires."
  type        = number
  default     = 1
}

variable "lambda_error_period_seconds" {
  description = "Length in seconds of each evaluation period for the Lambda error-rate alarm."
  type        = number
  default     = 300
}

variable "sqs_queue_depth_threshold" {
  description = "Number of visible messages in the SQS queue that triggers the queue-depth alarm."
  type        = number
  default     = 50
}

variable "sqs_queue_depth_evaluation_periods" {
  description = "Number of consecutive periods the queue-depth threshold must be breached before the alarm fires."
  type        = number
  default     = 2
}

variable "sqs_queue_depth_period_seconds" {
  description = "Length in seconds of each evaluation period for the SQS queue-depth alarm."
  type        = number
  default     = 300
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget limit in USD for this project. Triggers a notification at 80% of this amount."
  type        = number
  default     = 20
}

variable "budget_notification_threshold_percent" {
  description = "Percentage of the monthly budget that triggers the email notification."
  type        = number
  default     = 80
}