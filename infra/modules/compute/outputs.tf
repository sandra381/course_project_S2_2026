output "function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the Lambda function as it appears in AWS"
  value       = aws_lambda_function.this.function_name
}

output "role_arn" {
  description = "ARN of the IAM execution role assigned to the Lambda function"
  value       = aws_iam_role.lambda_exec.arn
}