
output "vpc_link_id" {
  value = aws_api_gateway_vpc_link.internal.id
}

output "internal_nlb_dns_name" {
  value = aws_lb.internal_nlb.dns_name
}
