
output "db_instance_address" {
  value = aws_db_instance.postgresql.address
}

output "db_instance_identifier" {
  value = aws_db_instance.postgresql.identifier
}

output "redis_primary_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "dynamodb_gps_table_name" {
  value = aws_dynamodb_table.gps_locations.name
}

output "dynamodb_notifications_table_name" {
  value = aws_dynamodb_table.notifications.name
}

output "s3_reportes_bucket" {
  value = aws_s3_bucket.reportes.bucket
}

output "s3_reportes_bucket_arn" {
  value = aws_s3_bucket.reportes.arn
}

output "vpc_endpoint_dynamodb_id" {
  value = aws_vpc_endpoint.dynamodb.id
}

output "vpc_endpoint_s3_id" {
  value = aws_vpc_endpoint.s3.id
}
