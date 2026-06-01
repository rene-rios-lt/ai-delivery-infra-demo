output "db_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance"
  value       = aws_db_instance.this.endpoint
  sensitive   = true
}

output "db_address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.this.address
  sensitive   = true
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "db_port" {
  description = "Port the RDS instance listens on"
  value       = aws_db_instance.this.port
}

output "db_sg_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.rds.id
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials and connection string"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_instance_id" {
  description = "Identifier of the RDS DB instance"
  value       = aws_db_instance.this.identifier
}
