resource "aws_route53_zone" "subdomain" {
  count = var.create_dns_zone ? 1 : 0

  name = var.root_domain_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-zone"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

locals {
  route53_zone_id = var.create_dns_zone ? aws_route53_zone.subdomain[0].zone_id : var.hosted_zone_id
}

output "name_servers" {
  description = "Name servers of the Route 53 hosted zone. Only populated when this environment creates the zone."
  value       = var.create_dns_zone ? aws_route53_zone.subdomain[0].name_servers : []
}

output "zone_id" {
  description = "Route 53 hosted zone ID used to create DNS records."
  value       = local.route53_zone_id
}