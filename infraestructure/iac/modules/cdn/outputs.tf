
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.main.arn
}

output "s3_frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}

output "s3_frontend_bucket_arn" {
  value = aws_s3_bucket.frontend.arn
}
