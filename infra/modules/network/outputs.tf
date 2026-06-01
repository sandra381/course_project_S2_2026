output "vpc_id" {
  description = "ID of the VPC created by this module."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways created."
  value       = aws_nat_gateway.this[*].id
}

output "web_sg_id" {
  description = "ID of the web security group (public ingress)."
  value       = aws_security_group.web_sg.id
}

output "app_sg_id" {
  description = "ID of the app security group (Lambda functions)."
  value       = aws_security_group.app_sg.id
}

output "db_sg_id" {
  description = "ID of the database security group (RDS MySQL)."
  value       = aws_security_group.db_sg.id
}