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
  description = "Prefix for the S3 bucket name. The environment and a random suffix are appended automatically to ensure global uniqueness."
  type        = string
  default     = "app-assets"
}
