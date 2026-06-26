output "endpoint" {
  description = "RDS instance endpoint hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "secret_arn" {
  description = "Secrets Manager secret ARN containing RDS credentials"
  value       = aws_secretsmanager_secret.rds.arn
  sensitive   = true
}
