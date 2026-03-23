output "db_endpoint" {
  description = "Endpoint подключения к базе данных"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "Имя базы данных"
  value       = aws_db_instance.main.db_name
}
