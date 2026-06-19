locals {
  prefix = "${var.project_name}-${var.environment}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# LOG GROUPS — uno por cada función Lambda (api, worker, cleanup)
# El nombre usa el prefijo de ambiente para evitar colisiones entre dev/staging.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_cloudwatch_log_group" "lambda" {
  for_each = var.lambda_function_names

  name              = "/${var.environment}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.prefix}-${each.key}-logs"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SNS TOPIC — notificaciones por email para alarmas y presupuesto
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"

  tags = {
    Name        = "${local.prefix}-alerts"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

# ═══════════════════════════════════════════════════════════════════════════════
# ALARMA 1 — Errores de Lambda API
# Se dispara si la función API acumula más de N errores en el período definido.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_cloudwatch_metric_alarm" "lambda_api_errors" {
  alarm_name          = "${local.prefix}-lambda-api-errors"
  alarm_description   = "Se dispara cuando Lambda API supera ${var.lambda_error_threshold} errores en ${var.lambda_error_period_seconds}s. Indica fallos en la lógica de negocio o problemas de conexión a RDS/S3."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.lambda_error_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.lambda_error_period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_api_function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name      = "${local.prefix}-lambda-api-errors"
    ManagedBy = "terraform"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# ALARMA 2 — Profundidad de cola SQS
# Se dispara si los mensajes visibles en la cola se acumulan, lo que indica
# que Lambda Worker no está procesando al ritmo necesario.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  alarm_name          = "${local.prefix}-sqs-queue-depth"
  alarm_description   = "Se dispara cuando la cola SQS acumula más de ${var.sqs_queue_depth_threshold} mensajes visibles durante ${var.sqs_queue_depth_evaluation_periods} períodos consecutivos. Indica que Lambda Worker no está procesando al ritmo de llegada de jobs."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.sqs_queue_depth_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.sqs_queue_depth_period_seconds
  statistic           = "Average"
  threshold           = var.sqs_queue_depth_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.sqs_queue_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name      = "${local.prefix}-sqs-queue-depth"
    ManagedBy = "terraform"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DASHBOARD — 3 widgets: request count, error rate, queue depth
# El body se genera con jsonencode() referenciando variables — no hay
# nombres de métricas ni ARNs hardcodeados como string literal.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "API Gateway — Request Count"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", var.api_gateway_id, { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Lambda API — Error Rate"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_api_function_name, { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "SQS — Queue Depth (mensajes visibles)"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_queue_name, { stat = "Average", period = 300 }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}

data "aws_region" "current" {}

# ═══════════════════════════════════════════════════════════════════════════════
# COST BUDGET — alerta cuando el gasto mensual supera el 80% del límite
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_budgets_budget" "monthly" {
  name         = "${local.prefix}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.budget_notification_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [aws_sns_topic.alerts.arn]
  }
}
