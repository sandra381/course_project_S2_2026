# ─── MODULO DE RED ─────────────────────────────────────────────────────────────
module "network" {
  source               = "./modules/network"
  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  single_nat_gateway   = var.single_nat_gateway
}

# ─── BUCKET S3 ORIGINAL DEL DELIVERY 1 ────────────────────────────────────────
resource "aws_s3_bucket" "app_assets" {
  bucket = "${var.project_name}-${var.app_bucket_prefix}-${var.environment}"

  tags = {
    Name        = "${var.project_name}-${var.app_bucket_prefix}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ─── MODULO DE STORAGE — bucket para archivos CSV ──────────────────────────────
module "storage_files" {
  source       = "./modules/storage"
  environment  = var.environment
  project_name = var.project_name
  bucket_name  = "files"
}

# ─── MODULO DE STORAGE — bucket para reportes PDF ─────────────────────────────
module "storage_reports" {
  source       = "./modules/storage"
  environment  = var.environment
  project_name = var.project_name
  bucket_name  = "reports"
}

# ─── MODULO DE BASE DE DATOS — RDS MySQL ───────────────────────────────────────
module "database" {
  source         = "./modules/database"
  environment    = var.environment
  project_name   = var.project_name
  db_name        = "spvr"
  db_username    = var.db_username
  db_password    = var.db_password
  instance_class = "db.t3.micro"
  multi_az       = false
  subnet_ids     = module.network.private_subnet_ids
  vpc_id         = module.network.vpc_id
  db_sg_id       = module.network.db_sg_id
}

# ─── MODULO DE COMPUTO — Lambda API ────────────────────────────────────────────
module "compute" {
  source                 = "./modules/compute"
  environment            = var.environment
  project_name           = var.project_name
  name                   = "api"
  memory_size            = 512
  timeout                = 30
  s3_bucket_arn          = module.storage_files.bucket_arn
  s3_bucket_name         = module.storage_files.bucket_name
  s3_reports_bucket_name = module.storage_reports.bucket_name
  db_host                = module.database.db_endpoint
  db_name                = module.database.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  subnet_ids             = module.network.private_subnet_ids
  security_group_ids     = [module.network.app_sg_id]

  sqs_queue_arn                      = module.async.queue_arn
  sqs_queue_url                      = module.async.queue_url
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.maximum_batching_window_in_seconds
  bisect_batch_on_function_error     = var.bisect_batch_on_function_error
}
# ─── MODULO DE INGRESS — API Gateway ───────────────────────────────────────────
module "ingress" {
  source                   = "./modules/ingress"
  project_name             = var.project_name
  environment              = var.environment
  lambda_api_function_name = module.compute.function_name
  lambda_api_invoke_arn    = module.compute.invoke_arn
  health_check_path        = var.health_check_path
}

# ─── MODULO ASYNC — SQS + DLQ ───────────────────────────────────────────
module "async" {
  source = "./modules/async"

  queue_name_prefix             = var.queue_name_prefix
  visibility_timeout_seconds    = var.visibility_timeout_seconds
  message_retention_seconds     = var.message_retention_seconds
  max_receive_count             = var.max_receive_count
  dlq_message_retention_seconds = var.dlq_message_retention_seconds
}

# ─── MODULO SCHEDULER — EventBridge + Lambda Cleanup ─────────────────────
module "scheduler" {
  source = "./modules/scheduler"

  project_name        = var.project_name
  environment         = var.environment
  schedule_expression = var.schedule_expression
  scheduler_timezone  = var.scheduler_timezone
  stale_hours         = var.stale_hours
  subnet_ids          = module.network.private_subnet_ids
  security_group_ids  = [module.network.app_sg_id]
  db_host             = module.database.db_endpoint
  db_name             = module.database.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  pymysql_layer_arn   = module.compute.pymysql_layer_arn
}
