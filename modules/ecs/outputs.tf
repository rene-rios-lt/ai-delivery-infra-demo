output "ecs_sg_id" {
  description = "Security group ID of the ECS tasks — pass this to the RDS module"
  value       = aws_security_group.ecs.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.api.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.api.id
}

output "task_definition_arn" {
  description = "ARN of the latest ECS task definition"
  value       = aws_ecs_task_definition.api.arn
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for ECS task logs"
  value       = aws_cloudwatch_log_group.ecs.name
}
