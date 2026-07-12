output "s3_bucket_name" {
  description = "Nombre del bucket S3 donde se sube el frontend"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_domain_name" {
  description = "URL pública del sitio (usar esta para acceder al frontend)"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución de CloudFront (se usa para invalidar caché en el CI/CD)"
  value       = aws_cloudfront_distribution.frontend.id
}
