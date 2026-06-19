output "db_endpoint" {
  description = "Connection endpoint of the RDS instance (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_name" {
  description = "Name of the MySQL database created inside the RDS instance"
  value       = aws_db_instance.this.db_name
}

output "db_port" {
  description = "Port on which the RDS instance accepts connections"
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "ID of the security group attached to the RDS instance"
  value       = var.db_sg_id
}

output "db_instance_arn" {
  description = "ARN of the RDS database instance. Consumed by infra/modules/iam/ to scope the compute role's RDS permissions."
  value       = aws_db_instance.this.arn
}