variable "queue_name_prefix" {
  description = "Prefijo para nombrar la cola principal y la DLQ. Ejemplo: spvr-jobs produce spvr-jobs-queue y spvr-jobs-dlq."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Segundos que un mensaje es invisible mientras Lambda Worker lo procesa. Debe ser mayor o igual al timeout de Lambda Worker (actualmente 30s en el proyecto)."
  type        = number
}

variable "message_retention_seconds" {
  description = "Segundos que la cola principal retiene un mensaje antes de eliminarlo. Si Lambda Worker no lo procesa en este tiempo, el mensaje se pierde."
  type        = number
}

variable "max_receive_count" {
  description = "Veces máximas que Lambda Worker puede intentar procesar un mensaje antes de que SQS lo mueva automáticamente a la DLQ."
  type        = number
}

variable "dlq_message_retention_seconds" {
  description = "Segundos que la DLQ retiene mensajes fallidos. Debe dar tiempo suficiente al administrador para inspeccionar errores desde el dashboard."
  type        = number
}