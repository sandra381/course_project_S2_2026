variable "project_name" {
  description = "Name of the project. Used as prefix for all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev or prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g. 10.0.0.0/16)."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. One per availability zone."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. One per availability zone."
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zone names to deploy subnets into (e.g. [us-east-1a, us-east-1b])."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "If true, a single NAT Gateway is created in the first public subnet. If false, one NAT Gateway per AZ is created."
  type        = bool
  default     = true
}