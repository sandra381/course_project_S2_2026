# ═══════════════════════════════════════════════════════════════════════════════
# CLOUDFRONT — redirect HTTP → HTTPS delante de API Gateway
# API Gateway HTTP API no soporta escuchar en puerto 80, así que CloudFront
# actúa como "portero": acepta tráfico HTTP y HTTPS, y redirige todo lo que
# llega por HTTP hacia HTTPS antes de pasarlo a API Gateway.
# ═══════════════════════════════════════════════════════════════════════════════

# ─── DISTRIBUCION CLOUDFRONT ──────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name}-${var.environment}-api-cdn"

  origin {
    domain_name = trimprefix(trimsuffix(module.ingress.api_endpoint, "/"), "https://")
    origin_id   = "api-gateway-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only" # CloudFront siempre habla HTTPS con API Gateway
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "api-gateway-origin"

    # Esta línea es la que hace el redirect HTTP -> HTTPS automáticamente.
    # Si alguien entra por http://, CloudFront responde 301 hacia https://
    viewer_protocol_policy = var.redirect_http_to_https

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Accept"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0 # no cachear respuestas de la API por defecto
    max_ttl     = 0
  }

  aliases = [var.api_domain_name]

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.api.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = var.ssl_policy_name
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-cdn"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ─── OUTPUT ───────────────────────────────────────────────────────────────────
output "cloudfront_domain_name" {
  description = "Dominio interno de CloudFront generado por AWS (ej: d123abc.cloudfront.net). Útil para depurar."
  value       = aws_cloudfront_distribution.api.domain_name
}