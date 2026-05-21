# Obtener datos de la VPC default
data "aws_vpc" "default" {
  default = true
}

# Obtener las subnets de la VPC default
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Bucket S3 original del Delivery 1
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

# Módulo de cómputo — Lambda
module "compute" {
  source        = "./modules/compute"
  environment   = var.environment
  project_name  = var.project_name
  name          = "file-processor"
  memory_size   = 512
  timeout       = 30
  s3_bucket_arn = module.storage_files.bucket_arn
}

# Módulo de storage — bucket para archivos CSV
module "storage_files" {
  source       = "./modules/storage"
  environment  = var.environment
  project_name = var.project_name
  bucket_name  = "files"
}

# Módulo de storage — bucket para reportes PDF
module "storage_reports" {
  source       = "./modules/storage"
  environment  = var.environment
  project_name = var.project_name
  bucket_name  = "reports"
}

# Módulo de base de datos — RDS MySQL
module "database" {
  source         = "./modules/database"
  environment    = var.environment
  project_name   = var.project_name
  db_name        = "spvr"
  db_username    = var.db_username
  db_password    = var.db_password
  instance_class = "db.t3.micro"
  multi_az       = false
  subnet_ids     = data.aws_subnets.default.ids
  vpc_id         = data.aws_vpc.default.id
}