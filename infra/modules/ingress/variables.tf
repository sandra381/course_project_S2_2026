variable "project_name" {
  description = "Name of the project. Used as prefix for all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev or prod)."
  type        = string
}

variable "lambda_api_function_name" {
  description = "Name of the Lambda API function to integrate with API Gateway."
  type        = string
}

variable "lambda_api_invoke_arn" {
  description = "Invoke ARN of the Lambda API function."
  type        = string
}

variable "health_check_path" {
  description = "Path used for health checks on the API Gateway stage."
  type        = string
  default     = "/"
}