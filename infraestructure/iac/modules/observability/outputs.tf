

output "cloudtrail_arn" {
  value = aws_cloudtrail.main.arn
}

output "cloudtrail_logs_bucket" {
  value = aws_s3_bucket.cloudtrail_logs.bucket
}

output "config_recorder_name" {
  description = "Nombre del AWS Config Recorder -- null en los entornos con manage_config_recorder = false (no lo crean, ver variables.tf)"
  value       = var.manage_config_recorder ? aws_config_configuration_recorder.main[0].name : null
}

