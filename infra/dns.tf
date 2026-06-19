# ─── ROUTE 53 HOSTED ZONE — subdominio delegado por el ingeniero ─────────────
resource "aws_route53_zone" "subdomain" {
  name = "grupo1.oyd.solid.com.gt"

  tags = {
    Name        = "${var.project_name}-${var.environment}-zone"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ─── OUTPUT — Name Servers ─────────────────────────────────────────────────────
output "name_servers" {
  description = "Name servers de la zona Route 53."
  value       = aws_route53_zone.subdomain.name_servers
}

output "zone_id" {
  description = "ID de la hosted zone. Se usa para crear registros DNS (validación de certificados ACM, etc.) dentro de este subdominio."
  value       = aws_route53_zone.subdomain.zone_id
}