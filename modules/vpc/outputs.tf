output "vpc_id" {
  description = "VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "subnet"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "APP"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "DB"
  value       = aws_subnet.private_db[*].id
}