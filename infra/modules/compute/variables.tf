variable "environment" {
    description = "Deployment environment (dev or prod)"
    type        = string
}

variable "name" {
    description = "Name of the Lambda function"
    type        = string
}

variable "memory_size" {
    description = "Amount of memory in MB allocated to the Lambda function"
    type        = number
    default     = 512
}

variable "timeout" {
    description = "Timeout in seconds for the Lambda function execution"
    type        = number
    default     = 30
}

variable "project_name" {
    description = "Name of the project, used as prefix in resource names"
    type        = string
}

variable "s3_bucket_arn" {
    description = "ARN of the S3 bucket that the Lambda function is allowed to read from and write to"
    type        = string
}