output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket as it appears in AWS"
  value       = aws_s3_bucket.this.id
}

output "bucket_url" {
  description = "S3 URL of the bucket"
  value       = "s3://${aws_s3_bucket.this.id}"
}