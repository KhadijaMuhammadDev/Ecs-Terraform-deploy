# infrastructure/outputs.tf

output "ecs_cluster_name" {
  description = " ECS Cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  description = " URL  ECR.  GitHub Actions."
  value       = aws_ecr_repository.app_repo.repository_url
}

output "private_subnets" {
  description = "IDs   .  Task Definition."
  value       = aws_subnet.private[*].id
}

output "ecs_tasks_sg_id" {
  description = "Security Group ID  ECS."
  value       = aws_security_group.ecs_tasks.id
}


output "rds_secret_arn" {
  description = "ARN ـ Secrets Manager     RDS."
  value       = aws_secretsmanager_secret.db_credentials.arn
}