variable "environment" {
  description = "Deployment environment (dev, staging, prod). Used as prefix in all resource names."
  type        = string
}

variable "project_name" {
  description = "Project name used as prefix in all resource names to avoid collisions."
  type        = string
}

# ─── RECURSOS QUE CONSUMEN LOS ROLES ─────────────────────────────────────────

variable "s3_files_bucket_arn" {
  description = "ARN of the S3 files bucket. Granted to lambda_api (read/write) and lambda_worker (read)."
  type        = string
}

variable "s3_reports_bucket_arn" {
  description = "ARN of the S3 reports bucket. Granted to lambda_api (write) and lambda_worker (write)."
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the main SQS queue. Granted SendMessage to lambda_api and ReceiveMessage/Delete to lambda_worker."
  type        = string
}

variable "db_instance_arn" {
  description = "ARN of the RDS database instance. Granted DescribeDBInstances to the compute role (lambda_api)."
  type        = string
}

# ─── OIDC / CI RUNNER ────────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub organization or username that owns the repository. Used to scope the OIDC trust policy."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name. Used to scope the OIDC trust policy to repo:<org>/<repo>:ref:refs/heads/main."
  type        = string
}

variable "tf_state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform remote state (created in bootstrap workspace). Used in the CI runner policy."
  type        = string
}

variable "tf_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking (created in bootstrap workspace). Used in the CI runner policy."
  type        = string
}