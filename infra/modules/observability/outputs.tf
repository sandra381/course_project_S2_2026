# ─── LOG GROUPS ───────────────────────────────────────────────────────────────
output "log_group_arns" {
  description = "ARNs of all CloudWatch log groups created for the Lambda functions."
  value       = { for k, v in aws_cloudwatch_log_group.lambda : k => v.arn }
}

output "log_group_names" {
  description = "Names of all CloudWatch log groups created for the Lambda functions."
  value       = { for k, v in aws_cloudwatch_log_group.lambda : k => v.name }
}

# ─── ALARMS ───────────────────────────────────────────────────────────────────
output "lambda_api_errors_alarm_arn" {
  description = "ARN of the Lambda API error-rate alarm."
  value       = aws_cloudwatch_metric_alarm.lambda_api_errors.arn
}

output "sqs_queue_depth_alarm_arn" {
  description = "ARN of the SQS queue-depth alarm."
  value       = aws_cloudwatch_metric_alarm.sqs_queue_depth.arn
}

# ─── SNS ──────────────────────────────────────────────────────────────────────
output "sns_topic_arn" {
  description = "ARN of the SNS topic used for alarm and budget notifications."
  value       = aws_sns_topic.alerts.arn
}

# ─── DASHBOARD ────────────────────────────────────────────────────────────────
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "Direct console URL to view the CloudWatch dashboard."
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

# ─── BUDGET ───────────────────────────────────────────────────────────────────
output "budget_name" {
  description = "Name of the monthly cost budget."
  value       = aws_budgets_budget.monthly.name
}