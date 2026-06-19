output "queue_url" {
  description = "URL de la cola SQS principal. Se inyecta como SQS_QUEUE_URL en Lambda Worker para que sepa dónde leer mensajes."
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "ARN de la cola SQS principal. Se usa en el event source mapping y en la política IAM de Lambda Worker."
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "Name of the main SQS queue. Used by the observability module to reference the queue in alarms and dashboard widgets."
  value       = aws_sqs_queue.main.name
}

output "dlq_url" {
  description = "URL de la Dead Letter Queue spvr-jobs-dlq. Para inspección manual de mensajes fallidos desde la consola AWS."
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN de la Dead Letter Queue. Referenciado en el redrive_policy de la cola principal."
  value       = aws_sqs_queue.dlq.arn
}