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

# ─── VARIABLES DE RED (D3) ─────────────────────────────────────────────────────

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