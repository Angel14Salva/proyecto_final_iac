
output "cloudtrail_arn" {
  value = aws_cloudtrail.main.arn
}

output "cloudtrail_logs_bucket" {
  value = aws_s3_bucket.cloudtrail_logs.bucket
}

output "config_recorder_name" {
  value = aws_config_configuration_recorder.main.name
}
