output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.compute.function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.compute.function_name
}

output "storage_files_bucket_name" {
  description = "Name of the S3 bucket for CSV files"
  value       = module.storage_files.bucket_name
}

output "storage_files_bucket_arn" {
  description = "ARN of the S3 bucket for CSV files"
  value       = module.storage_files.bucket_arn
}

output "storage_reports_bucket_name" {
  description = "Name of the S3 bucket for PDF reports"
  value       = module.storage_reports.bucket_name
}

output "storage_reports_bucket_arn" {
  description = "ARN of the S3 bucket for PDF reports"
  value       = module.storage_reports.bucket_arn
}

output "db_endpoint" {
  description = "Connection endpoint of the RDS MySQL instance"
  value       = module.database.db_endpoint
}

output "db_name" {
  description = "Name of the MySQL database"
  value       = module.database.db_name
}