# ─── EMPAQUETAR LAMBDA CLEANUP ────────────────────────────────────────────────
data "archive_file" "lambda_cleanup_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_cleanup.zip"

  source {
    content  = file("${path.module}/handler_cleanup.py")
    filename = "handler_cleanup.py"
  }
}

# ─── IAM ROLE — Lambda Cleanup ────────────────────────────────────────────────
# Role exclusivo para Lambda Cleanup. Separado del role de Lambda API/Worker
# para aplicar el principio de menor privilegio.
resource "aws_iam_role" "cleanup_exec" {
  name = "${var.project_name}-${var.environment}-cleanup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-cleanup-role"
    ManagedBy = "terraform"
  }
}

# ─── IAM POLICY — VPC access para Lambda Cleanup ──────────────────────────────
resource "aws_iam_role_policy_attachment" "cleanup_vpc" {
  role       = aws_iam_role.cleanup_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ─── LAMBDA CLEANUP ───────────────────────────────────────────────────────────
# Lambda diferente a Lambda Worker — requerimiento explícito de la rúbrica.
# Se encarga de marcar como FALLIDO los jobs estancados en RDS.
resource "aws_lambda_function" "cleanup" {
  function_name    = "${var.project_name}-${var.environment}-cleanup"
  role             = aws_iam_role.cleanup_exec.arn
  handler          = "handler_cleanup.handler"
  runtime          = "python3.12"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.lambda_cleanup_zip.output_path
  source_code_hash = data.archive_file.lambda_cleanup_zip.output_base64sha256
  layers           = [var.pymysql_layer_arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
      STALE_HOURS = tostring(var.stale_hours)
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-cleanup"
    ManagedBy = "terraform"
  }
}

# ─── IAM ROLE — EventBridge Scheduler ────────────────────────────────────────
# Role exclusivo para el scheduler. Solo puede invocar Lambda Cleanup.
# Scoped al ARN específico — no usa wildcard *.
resource "aws_iam_role" "scheduler_exec" {
  name = "${var.project_name}-${var.environment}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-scheduler-role"
    ManagedBy = "terraform"
  }
}

# ─── IAM POLICY — Scheduler solo puede invocar Lambda Cleanup ─────────────────
resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "${var.project_name}-${var.environment}-scheduler-invoke-policy"
  role = aws_iam_role.scheduler_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.cleanup.arn
      }
    ]
  })
}

# ─── EVENTBRIDGE SCHEDULER ────────────────────────────────────────────────────
# Dispara Lambda Cleanup según schedule_expression.
# El role del scheduler solo puede invocar Lambda Cleanup — no tiene permisos
# sobre ningún otro recurso del sistema.
resource "aws_scheduler_schedule" "cleanup" {
  name       = "${var.project_name}-${var.environment}-cleanup-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.scheduler_timezone

  target {
    arn      = aws_lambda_function.cleanup.arn
    role_arn = aws_iam_role.scheduler_exec.arn

    input = jsonencode({
      source = "eventbridge-scheduler"
      action = "cleanup-stale-jobs"
    })
  }
}
