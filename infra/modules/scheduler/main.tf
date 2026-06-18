# ─── EMPAQUETAR LAMBDA CLEANUP ────────────────────────────────────────────────
data "archive_file" "lambda_cleanup_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_cleanup.zip"

  source {
    content  = file("${path.module}/handler_cleanup.py")
    filename = "handler_cleanup.py"
  }
}

# ─── LAMBDA CLEANUP ───────────────────────────────────────────────────────────
resource "aws_lambda_function" "cleanup" {
  function_name    = "${var.project_name}-${var.environment}-cleanup"
  role             = var.cleanup_role_arn
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
      DB_HOST       = var.db_host
      DB_NAME       = var.db_name
      DB_USER       = var.db_username
      DB_SECRET_ARN = var.db_secret_arn
      STALE_HOURS   = tostring(var.stale_hours)
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-cleanup"
    ManagedBy = "terraform"
  }
}

# ─── IAM POLICY — Scheduler solo puede invocar Lambda Cleanup ─────────────────
resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "${var.project_name}-${var.environment}-scheduler-invoke-policy"
  role = var.scheduler_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeCleanupOnly"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.cleanup.arn
      }
    ]
  })
}

# ─── EVENTBRIDGE SCHEDULER ────────────────────────────────────────────────────
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
    role_arn = var.scheduler_role_arn

    input = jsonencode({
      source = "eventbridge-scheduler"
      action = "cleanup-stale-jobs"
    })
  }
}
