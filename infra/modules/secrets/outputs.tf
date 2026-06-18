# ─── KMS ──────────────────────────────────────────────────────────────────────
output "kms_key_arn" {
  description = "ARN of the KMS CMK. Consumed by storage and database modules to encrypt S3 buckets and RDS."
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the KMS CMK."
  value       = aws_kms_key.main.key_id
}

output "kms_alias_name" {
  description = "Alias of the KMS CMK (e.g. alias/oyd-project-dev-cmk)."
  value       = aws_kms_alias.main.name
}

# ─── SECRETS MANAGER ──────────────────────────────────────────────────────────
output "secret_arn" {
  description = "ARN of the Secrets Manager secret storing the DB password. Injected as DB_SECRET_ARN env var into Lambda functions."
  value       = aws_secretsmanager_secret.db_password.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.db_password.name
}
