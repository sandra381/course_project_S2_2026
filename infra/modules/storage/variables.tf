variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project, used as prefix in bucket name"
  type        = string
}

variable "bucket_name" {
  description = "Suffix for the S3 bucket name. Combined with project_name and environment to form the full name"
  type        = string
}