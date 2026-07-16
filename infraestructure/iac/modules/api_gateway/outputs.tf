
output "rest_api_id" {
  value = aws_api_gateway_rest_api.segat.id
}

output "invoke_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}

output "stage_arn" {
  value = aws_api_gateway_stage.prod.arn
}
