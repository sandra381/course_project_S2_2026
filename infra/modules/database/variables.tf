variable "environment" {
  description = "Deployment environment (dev or prod)."
  type        = string
}

variable "project_name" {
  description = "Name of the project, used as prefix in resource names."
  type        = string
}

variable "db_name" {
  description = "Name of MySQL database to create inside the RDS instance."
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance. Must not appear in any committed file."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class that defines CPU and memory (e.g. db.t3.micro)."
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Whether to deploy RDS in multiple availability zones for high availability."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of private subnet IDs where the RDS instance will be placed."
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC where the RDS subnet group will be created."
  type        = string
}

variable "db_sg_id" {
  description = "ID of the database security group created by the network module."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt the RDS instance. Provided by module.secrets.kms_key_arn."
  type        = string
}
