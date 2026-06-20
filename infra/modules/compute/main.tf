# ─── EMPAQUETAR LAMBDA API ─────────────────────────────────────────────────────
data "archive_file" "lambda_api_zip" {
  type             = "zip"
  output_path      = "${path.module}/lambda_api.zip"
  output_file_mode = "0666"

  source {
    content  = file("${path.module}/handler_api.py")
    filename = "handler_api.py"
  }
}

# ─── EMPAQUETAR LAMBDA WORKER ──────────────────────────────────────────────────
data "archive_file" "lambda_worker_zip" {
  type             = "zip"
  output_path      = "${path.module}/lambda_worker.zip"
  output_file_mode = "0666"

  source {
    content  = file("${path.module}/handler_worker.py")
    filename = "handler_worker.py"
  }
}

# ─── LAMBDA LAYER — pymysql ────────────────────────────────────────────────────
resource "aws_lambda_layer_version" "pymysql" {
  filename            = "${path.module}/pymysql_layer.zip"
  layer_name          = "${var.project_name}-${var.environment}-pymysql"
  compatible_runtimes = ["python3.12"]
  description         = "pymysql library for MySQL connections from Lambda"
}

resource "aws_lambda_layer_version" "bcrypt" {
  filename            = "${path.module}/bcrypt_layer.zip"
  layer_name          = "${var.project_name}-${var.environment}-bcrypt"
  compatible_runtimes = ["python3.12"]
  description         = "bcrypt library for password hashing in Lambda API"
}

resource "aws_lambda_layer_version" "jwt" {
  filename            = "${path.module}/jwt_layer.zip"
  layer_name          = "${var.project_name}-${var.environment}-jwt"
  compatible_runtimes = ["python3.12"]
  description         = "PyJWT library for token generation in Lambda API"
}

# ─── LAMBDA API ────────────────────────────────────────────────────────────────
resource "aws_lambda_function" "api" {
  function_name    = "${var.project_name}-${var.environment}-api"
  role             = var.api_role_arn
  handler          = "handler_api.handler"
  runtime          = "python3.12"
  memory_size      = var.memory_size
  timeout          = var.timeout
  filename         = data.archive_file.lambda_api_zip.output_path
  source_code_hash = filebase64sha256("${path.module}/handler_api.py")
  layers           = [aws_lambda_layer_version.pymysql.arn, aws_lambda_layer_version.bcrypt.arn, aws_lambda_layer_version.jwt.arn]

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
      DB_SECRET_ARN     = var.db_secret_arn
      JWT_SECRET        = var.jwt_secret
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
  role             = var.worker_role_arn
  handler          = "handler_worker.handler"
  runtime          = "python3.12"
  memory_size      = var.memory_size
  timeout          = var.timeout
  filename         = data.archive_file.lambda_worker_zip.output_path
  source_code_hash = filebase64sha256("${path.module}/handler_worker.py")

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
      DB_SECRET_ARN     = var.db_secret_arn
      S3_REPORTS_BUCKET = var.s3_reports_bucket_name
      SQS_QUEUE_URL     = var.sqs_queue_url
      SES_SENDER_EMAIL  = var.ses_sender_email
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-worker"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ─── EVENT SOURCE MAPPING — SQS → Lambda Worker  ─────────────────────────
resource "aws_lambda_event_source_mapping" "sqs_worker" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.worker.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.maximum_batching_window_in_seconds
  //bisect_batch_on_function_error     = var.bisect_batch_on_function_error
  enabled = true
}


