variable "environment" {
  description = "Deployment environment (dev, staging, prod). Used as prefix in log group names."
  type        = string
}

variable "project_name" {
  description = "Project name used as prefix in all resource names."
  type        = string
}

# ─── LOG GROUPS ───────────────────────────────────────────────────────────────
variable "log_retention_days" {
  description = "Number of days CloudWatch Logs retains log events before automatic expiration."
  type        = number
  default     = 14
}

variable "lambda_function_names" {
  description = "Map of Lambda function names (api, worker, cleanup) to create one log group per compute resource."
  type        = map(string)
}

# ─── ALARMS ───────────────────────────────────────────────────────────────────
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
  description = "Number of visible messages in the SQS queue that triggers the queue-depth alarm (signals the worker may be falling behind)."
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

# ─── RESOURCE IDENTIFIERS (para el dashboard) ────────────────────────────────
variable "api_gateway_id" {
  description = "ID of the API Gateway HTTP API. Used as the dashboard's request-count metric dimension."
  type        = string
}

variable "lambda_api_function_name" {
  description = "Name of the Lambda API function. Used as the dashboard's error-rate metric dimension."
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the main SQS queue. Used as the dashboard's third widget metric dimension (queue depth)."
  type        = string
}

# ─── BUDGET ───────────────────────────────────────────────────────────────────
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
