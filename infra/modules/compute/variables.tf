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