variable "ses_sender_email" {
  description = "Email remitente verificado en SES, usado como 'From' en los correos de notificación de reportes."
  type        = string
}

variable "ses_test_user_emails" {
  description = "Lista de emails de usuarios de prueba (analistas y vendedores) a verificar en SES para la demo en modo sandbox."
  type        = list(string)
  default     = []
}

# ─── IDENTIDAD DEL REMITENTE ────────────────────────────────────────────────────
resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

# ─── IDENTIDADES DE USUARIOS DE PRUEBA (destinatarios) ───────────────────────
# for_each crea una identidad por cada email de la lista, sin repetir el bloque.
resource "aws_ses_email_identity" "test_users" {
  for_each = toset(var.ses_test_user_emails)
  email    = each.value
}

# ─── OUTPUTS ──────────────────────────────────────────────────────────────────
output "ses_sender_identity_arn" {
  description = "ARN of the verified SES sender identity."
  value       = aws_ses_email_identity.sender.arn
}

output "ses_test_user_identity_arns" {
  description = "ARNs of all test user SES identities created for sandbox testing."
  value       = { for k, v in aws_ses_email_identity.test_users : k => v.arn }
}