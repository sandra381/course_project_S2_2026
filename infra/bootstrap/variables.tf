variable "project_name" {
  description = "Name of the project, used as prefix in resource names"
  type        = string
  default     = "oyd-project"
}

variable "region" {
  description = "AWS region where the state bucket and lock table will be created"
  type        = string
  default     = "us-east-1"
}