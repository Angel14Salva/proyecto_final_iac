

output "sqs_reportes_arn" {
  value = aws_sqs_queue.reportes.arn
}

output "sqs_reportes_url" {
  value = aws_sqs_queue.reportes.url
}

output "sqs_reportes_dlq_arn" {
  value = aws_sqs_queue.reportes_dlq.arn
}

output "sqs_reportes_dlq_name" {
  value = aws_sqs_queue.reportes_dlq.name
}

output "sqs_notificaciones_arn" {
  value = aws_sqs_queue.notificaciones.arn
}

output "sqs_notificaciones_url" {
  value = aws_sqs_queue.notificaciones.url
}

output "sqs_notificaciones_dlq_arn" {
  value = aws_sqs_queue.notificaciones_dlq.arn
}

output "sns_negocio_arn" {
  value = aws_sns_topic.negocio.arn
}

output "sns_alertas_arn" {
  value = aws_sns_topic.alertas.arn
}

# CloudTrail (modules.observability) necesita el nombre corto, no el ARN --
# la API de CloudTrail acepta ambos al escribir pero siempre normaliza a
# nombre corto al leer, causando un diff perpetuo si se le pasa el ARN.
output "sns_alertas_name" {
  value = aws_sns_topic.alertas.name
}

output "sns_alertas_policy_id" {
  value = aws_sns_topic_policy.alertas.id
}

