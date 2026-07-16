
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_public_a_id" {
  value = aws_subnet.public_a.id
}

output "subnet_public_b_id" {
  value = aws_subnet.public_b.id
}

output "subnet_private_a_id" {
  value = aws_subnet.private_a.id
}

output "subnet_private_b_id" {
  value = aws_subnet.private_b.id
}

output "subnet_private_c_id" {
  value = aws_subnet.private_c.id
}

output "subnet_private_c2_id" {
  value = aws_subnet.private_c2.id
}

output "route_table_private_id" {
  value = aws_route_table.private.id
}

output "sg_alb_id" {
  value = aws_security_group.alb.id
}

output "sg_ecs_tasks_id" {
  value = aws_security_group.ecs_tasks.id
}

output "sg_rds_id" {
  value = aws_security_group.rds.id
}

output "sg_redis_id" {
  value = aws_security_group.redis.id
}
