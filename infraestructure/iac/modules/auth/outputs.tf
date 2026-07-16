
output "user_pool_id" {
  value = aws_cognito_user_pool.segat.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.segat.arn
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.segat_backend.id
}

output "user_pool_domain" {
  value = aws_cognito_user_pool_domain.segat.domain
}
