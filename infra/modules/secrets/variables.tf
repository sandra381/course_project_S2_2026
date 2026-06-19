variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "project_name" {
  description = "Project name used as prefix in all resource names."
  type        = string
}

variable "db_password" {
  description = "Database password to store in Secrets Manager. Must come from a sensitive Terraform variable — never hardcoded."
  type        = string
  sensitive   = true
}

variable "lambda_api_role_name" {
  description = "Name of the Lambda API IAM role. Used to grant GetSecretValue and KMS Decrypt permissions."
  type        = string
}

variable "lambda_worker_role_name" {
  description = "Name of the Lambda Worker IAM role. Used to grant GetSecretValue and KMS Decrypt permissions."
  type        = string
}

variable "lambda_cleanup_role_name" {
  description = "Name of the Lambda Cleanup IAM role. Used to grant GetSecretValue and KMS Decrypt permissions."
  type        = string
}
variable "lambda_api_role_arn" {
  description = "ARN of the Lambda API IAM role. Used in the KMS key policy LambdaDecrypt statement."
  type        = string
}

variable "lambda_worker_role_arn" {
  description = "ARN of the Lambda Worker IAM role. Used in the KMS key policy LambdaDecrypt statement."
  type        = string
}

variable "lambda_cleanup_role_arn" {
  description = "ARN of the Lambda Cleanup IAM role. Used in the KMS key policy LambdaDecrypt statement."
  type        = string
}