# ─── DATA SOURCES ─────────────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  prefix     = "${var.project_name}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ═══════════════════════════════════════════════════════════════════════════════
# KMS CMK — Customer Managed Key
# Reemplaza la encriptación SSE-S3 (AES256) de S3 y RDS por una llave propia.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_kms_key" "main" {
  description             = "CMK para encriptar S3, RDS y Secrets Manager del proyecto ${local.prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # Key policy — define exactamente quién puede usar esta llave y para qué.
  # - Root account: solo administración (no puede desencriptar datos)
  # - Lambda roles: solo Decrypt y GenerateDataKey (para leer datos)
  # - Secrets Manager: Decrypt y GenerateDataKey (para guardar y leer secrets)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = [
            var.lambda_api_role_arn,
            var.lambda_worker_role_arn,
            var.lambda_cleanup_role_arn
          ]
        }
        # Solo Decrypt y GenerateDataKey — no pueden administrar la llave
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = local.account_id
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${local.prefix}-cmk"
    ManagedBy = "terraform"
  }
}

# Alias legible para la llave — más fácil de identificar en la consola de AWS
resource "aws_kms_alias" "main" {
  name          = "alias/${local.prefix}-cmk"
  target_key_id = aws_kms_key.main.key_id
}

resource "time_sleep" "kms_propagation" {
  depends_on      = [aws_kms_key.main, aws_kms_alias.main]
  create_duration = "15s"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECRETS MANAGER — contraseña de base de datos
# Reemplaza el patrón TF_VAR_db_password / GitHub Secret / env var directa.
# Lambda recibe solo el ARN del secret, no la contraseña en texto plano.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.prefix}-db-password"
  description = "Contraseña de RDS MySQL para el proyecto ${local.prefix}. Recuperada por Lambda en runtime via GetSecretValue."
  #kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = 0 # 0 = borrado inmediato (útil en dev/staging para destroy limpio)

  depends_on = [time_sleep.kms_propagation] # asegurar que la llave KMS esté completamente propagada antes de crear el secret

  tags = {
    Name      = "${local.prefix}-db-password"
    ManagedBy = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password # viene de variable sensitive — nunca hardcodeado
}

# ═══════════════════════════════════════════════════════════════════════════════
# IAM — permisos adicionales a los roles Lambda para leer el secret y usar KMS
# Se adjuntan aquí (en el módulo secrets) para evitar dependencia circular con
# el módulo IAM, que no conoce los ARNs del secret ni de la llave KMS.
# ═══════════════════════════════════════════════════════════════════════════════

# ── Lambda API ─────────────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "lambda_api_secrets" {
  name = "${local.prefix}-lambda-api-secrets"
  role = var.lambda_api_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadDBSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_password.arn
      },
      {
        Sid      = "DecryptWithCMK"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

# ── Lambda Worker ──────────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "lambda_worker_secrets" {
  name = "${local.prefix}-lambda-worker-secrets"
  role = var.lambda_worker_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadDBSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_password.arn
      },
      {
        Sid      = "DecryptWithCMK"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

# ── Lambda Cleanup ─────────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "lambda_cleanup_secrets" {
  name = "${local.prefix}-lambda-cleanup-secrets"
  role = var.lambda_cleanup_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadDBSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_password.arn
      },
      {
        Sid      = "DecryptWithCMK"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}