# ─── EMPAQUETAR LAMBDA API ─────────────────────────────────────────────────────
data "archive_file" "lambda_api_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_api.zip"

  source {
    content  = file("${path.module}/handler_api.py")
    filename = "handler_api.py"
  }
}

# ─── EMPAQUETAR LAMBDA WORKER ──────────────────────────────────────────────────
data "archive_file" "lambda_worker_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_worker.zip"

  source {
    content  = file("${path.module}/handler_worker.py")
    filename = "handler_worker.py"
  }
}

# ─── IAM ROLE (compartido) ─────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-lambda-role"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ─── IAM POLICY — S3 ───────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-${var.environment}-lambda-s3-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.s3_reports_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─── IAM POLICY — VPC ──────────────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ─── LAMBDA LAYER — pymysql ────────────────────────────────────────────────────
resource "aws_lambda_layer_version" "pymysql" {
  filename            = "${path.module}/pymysql_layer.zip"
  layer_name          = "${var.project_name}-${var.environment}-pymysql"
  compatible_runtimes = ["python3.12"]
  description         = "pymysql library for MySQL connections from Lambda"
}

# ─── LAMBDA API ────────────────────────────────────────────────────────────────
resource "aws_lambda_function" "api" {
  function_name    = "${var.project_name}-${var.environment}-api"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler_api.handler"
  runtime          = "python3.12"
  memory_size      = var.memory_size
  timeout          = var.timeout
  filename         = data.archive_file.lambda_api_zip.output_path
  source_code_hash = data.archive_file.lambda_api_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.pymysql.arn]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      ENVIRONMENT       = var.environment
      PROJECT           = var.project_name
      S3_BUCKET_NAME    = var.s3_bucket_name
      S3_REPORTS_BUCKET = var.s3_reports_bucket_name
      SQS_QUEUE_URL     = var.sqs_queue_url
      DB_HOST           = var.db_host
      DB_NAME           = var.db_name
      DB_USER           = var.db_username
      DB_PASSWORD       = var.db_password
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_layer_version" "reportlab" {
  filename            = "${path.module}/reportlab_layer.zip"
  layer_name          = "${var.project_name}-${var.environment}-reportlab"
  compatible_runtimes = ["python3.12"]
  description         = "reportlab y pandas para generacion de PDFs en Lambda Worker"
}

# ─── LAMBDA WORKER ─────────────────────────────────────────────────────────────
resource "aws_lambda_function" "worker" {
  function_name    = "${var.project_name}-${var.environment}-worker"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler_worker.handler"
  runtime          = "python3.12"
  memory_size      = var.memory_size
  timeout          = var.timeout
  filename         = data.archive_file.lambda_worker_zip.output_path
  source_code_hash = data.archive_file.lambda_worker_zip.output_base64sha256

  layers = [
    aws_lambda_layer_version.pymysql.arn,
    aws_lambda_layer_version.reportlab.arn
  ]

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      ENVIRONMENT       = var.environment
      PROJECT           = var.project_name
      S3_BUCKET_NAME    = var.s3_bucket_name
      DB_HOST           = var.db_host
      DB_NAME           = var.db_name
      DB_USER           = var.db_username
      DB_PASSWORD       = var.db_password
      S3_REPORTS_BUCKET = var.s3_reports_bucket_name
      SQS_QUEUE_URL     = var.sqs_queue_url
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-worker"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ─── IAM POLICY — SQS ────────────────────────────────────────────────────
resource "aws_iam_role_policy" "lambda_sqs" {
  name = "${var.project_name}-${var.environment}-lambda-sqs-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# ─── EVENT SOURCE MAPPING — SQS → Lambda Worker  ─────────────────────────
resource "aws_lambda_event_source_mapping" "sqs_worker" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.worker.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.maximum_batching_window_in_seconds
  enabled                            = true
}
