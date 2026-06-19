# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM DOMAIN — ya NO se conecta directo a API Gateway.
# Con CloudFront en el medio (ver cloudfront.tf), el dominio público
# "api.grupo1.oyd.solid.com.gt" vive en CloudFront, no en API Gateway.
# API Gateway sigue siendo accesible por su URL autogenerada
# (*.execute-api.amazonaws.com) — eso es lo que CloudFront usa como "origin"
# por detrás, sin necesidad de que API Gateway tenga su propio dominio custom.
# ═══════════════════════════════════════════════════════════════════════════════

# ─── REGISTRO DNS — apunta el dominio público hacia CloudFront ──────────────
# Reemplaza el registro anterior que apuntaba directo a API Gateway.
resource "aws_route53_record" "api" {
  zone_id = local.route53_zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}

# ─── OUTPUT ───────────────────────────────────────────────────────────────────
output "custom_domain_url" {
  description = "Public HTTPS URL using the custom domain, served through CloudFront with HTTP->HTTPS redirect."
  value       = "https://${var.api_domain_name}/"
}