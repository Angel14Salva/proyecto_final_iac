
output "waf_main_arn" {
  value = aws_wafv2_web_acl.main.arn
}

output "waf_cloudfront_arn" {
  value = aws_wafv2_web_acl.cloudfront.arn
}
