output "cleanup_function_arn" {
  description = "ARN de Lambda Cleanup. Referenciado en la política IAM del scheduler."
  value       = aws_lambda_function.cleanup.arn
}

output "cleanup_function_name" {
  description = "Nombre de Lambda Cleanup. Útil para ver sus logs en CloudWatch."
  value       = aws_lambda_function.cleanup.function_name
}

output "scheduler_name" {
  description = "Nombre del schedule en EventBridge Scheduler."
  value       = aws_scheduler_schedule.cleanup.name
}