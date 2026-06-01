output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.api.arn
}

output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.api.function_name
}

output "role_arn" {
  description = "ARN of the IAM role attached to the Lambda function."
  value       = aws_iam_role.lambda_exec.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function. Used by API Gateway to integrate with Lambda."
  value       = aws_lambda_function.api.invoke_arn
}

output "worker_function_arn" {
  description = "ARN of the Lambda Worker function."
  value       = aws_lambda_function.worker.arn
}

output "worker_function_name" {
  description = "Name of the Lambda Worker function."
  value       = aws_lambda_function.worker.function_name
}