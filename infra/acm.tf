# ═══════════════════════════════════════════════════════════════════════════════
# CERTIFICADO ACM — TLS para el subdominio delegado
# Reemplaza la URL autogenerada *.execute-api.amazonaws.com (no soportada por
# ACM) por un dominio propio con certificado válido, según Deliverable D.
# ═══════════════════════════════════════════════════════════════════════════════

# ─── CERTIFICADO ────────────────────────────────────────────────────────────────
resource "aws_acm_certificate" "api" {
  domain_name       = var.api_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-cert"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ─── REGISTRO DNS DE VALIDACION ────────────────────────────────────────────────
# ACM exige probar que controlamos el dominio antes de emitir el certificado.
# Esto se hace creando un registro CNAME específico que ACM nos indica.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = local.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# ─── VALIDACION DEL CERTIFICADO ────────────────────────────────────────────────
# Espera a que ACM confirme que el registro DNS fue creado correctamente
# y el certificado pasa de estado "Pending validation" a "Issued".
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ─── OUTPUTS ──────────────────────────────────────────────────────────────────
output "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate for the custom domain."
  value       = aws_acm_certificate_validation.api.certificate_arn
}