output "api_endpoint" {
  description = "Public URL of the API Gateway endpoint. Use this to call the Lambda API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "ID of the API Gateway HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway. Used to scope Lambda permissions."
  value       = aws_apigatewayv2_api.this.execution_arn
}