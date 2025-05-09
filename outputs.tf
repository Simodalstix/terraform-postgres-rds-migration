output "bastion_instance_id" {
  description = "The EC2 instance ID of the Bastion host"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP for the Bastion (optional, not needed for SSM)"
  value       = aws_instance.bastion.public_ip
}

output "rds_endpoint" {
  description = "The RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN for RDS credentials"
  value       = aws_secretsmanager_secret.rds_secret.arn
}
