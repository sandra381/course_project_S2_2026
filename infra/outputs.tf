# ─── NETWORK OUTPUTS ───────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID of the VPC created by the network module."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = module.network.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways."
  value       = module.network.nat_gateway_ids
}

# ─── INGRESS OUTPUTS ───────────────────────────────────────────────────────────
output "api_endpoint" {
  description = "Public URL of the API Gateway endpoint."
  value       = module.ingress.api_endpoint
}

# ─── COMPUTE OUTPUTS ───────────────────────────────────────────────────────────
output "lambda_function_arn" {
  description = "ARN of the Lambda API function."
  value       = module.compute.function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda API function."
  value       = module.compute.function_name
}

# ─── STORAGE OUTPUTS ───────────────────────────────────────────────────────────
output "storage_files_bucket_name" {
  description = "Name of the S3 bucket for CSV files."
  value       = module.storage_files.bucket_name
}

output "storage_files_bucket_arn" {
  description = "ARN of the S3 bucket for CSV files."
  value       = module.storage_files.bucket_arn
}

output "storage_reports_bucket_name" {
  description = "Name of the S3 bucket for PDF reports."
  value       = module.storage_reports.bucket_name
}

output "storage_reports_bucket_arn" {
  description = "ARN of the S3 bucket for PDF reports."
  value       = module.storage_reports.bucket_arn
}

# ─── DATABASE OUTPUTS ──────────────────────────────────────────────────────────
output "db_endpoint" {
  description = "Connection endpoint of the RDS MySQL instance."
  value       = module.database.db_endpoint
}

output "db_name" {
  description = "Name of the MySQL database."
  value       = module.database.db_name
}

# ─── OUTPUTS ASYNC  ───────────────────────────────────────────────────────
output "sqs_queue_url" {
  description = "URL de la cola SQS principal spvr-jobs-queue."
  value       = module.async.queue_url
}

output "sqs_queue_arn" {
  description = "ARN de la cola SQS principal spvr-jobs-queue."
  value       = module.async.queue_arn
}

output "sqs_dlq_url" {
  description = "URL de la Dead Letter Queue spvr-jobs-dlq."
  value       = module.async.dlq_url
}

output "sqs_dlq_arn" {
  description = "ARN de la Dead Letter Queue spvr-jobs-dlq."
  value       = module.async.dlq_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt S3, RDS and Secrets Manager."
  value       = module.secrets.kms_key_arn
}

output "kms_alias_name" {
  description = "Alias of the KMS CMK."
  value       = module.secrets.kms_alias_name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret storing the DB password."
  value       = module.secrets.secret_arn
}

output "db_secret_name" {
  description = "Name of the Secrets Manager secret."
  value       = module.secrets.secret_name
}
output "observability_log_group_names" {
  description = "Names of all CloudWatch log groups created for the Lambda functions."
  value       = module.observability.log_group_names
}

output "observability_dashboard_url" {
  description = "Direct console URL to view the CloudWatch dashboard."
  value       = module.observability.dashboard_url
}

output "observability_sns_topic_arn" {
  description = "ARN of the SNS topic used for alarm and budget notifications."
  value       = module.observability.sns_topic_arn
}

output "observability_lambda_api_errors_alarm_arn" {
  description = "ARN of the Lambda API error-rate alarm."
  value       = module.observability.lambda_api_errors_alarm_arn
}

output "observability_sqs_queue_depth_alarm_arn" {
  description = "ARN of the SQS queue-depth alarm."
  value       = module.observability.sqs_queue_depth_alarm_arn
}

output "observability_budget_name" {
  description = "Name of the monthly cost budget."
  value       = module.observability.budget_name
}

# ─── IAM / CI RUNNER (Delivery 5 — Deliverable A/C evidence) ─────────────────
output "ci_runner_role_arn" {
  description = "ARN of the CI runner role assumable by GitHub Actions via OIDC."
  value       = module.iam.ci_runner_role_arn
}

output "lambda_api_role_arn" {
  description = "ARN of the Lambda API execution role."
  value       = module.iam.lambda_api_role_arn
}

output "lambda_worker_role_arn" {
  description = "ARN of the Lambda Worker execution role."
  value       = module.iam.lambda_worker_role_arn
}

output "lambda_cleanup_role_arn" {
  description = "ARN of the Lambda Cleanup execution role."
  value       = module.iam.lambda_cleanup_role_arn
}