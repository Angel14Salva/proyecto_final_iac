
output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "name_servers" {
  value = aws_route53_zone.main.name_servers
}

output "record_fqdn" {
  value = aws_route53_record.alb_external.fqdn
}
