output "app_bucket_name" {
  description = "Name of the S3 bucket created for application assets. Used by application deployments to upload static files or artifacts."
  value       = aws_s3_bucket.app_assets.bucket
}

output "app_bucket_arn" {
  description = "ARN of the S3 bucket. Used by IAM policy documents in downstream modules to grant least-privilege access."
  value       = aws_s3_bucket.app_assets.arn
}