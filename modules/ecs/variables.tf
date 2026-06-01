variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private app subnet IDs for the ECS service"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID of the ALB (allowed to reach ECS on port 8080)"
  type        = string
}

variable "rds_sg_id" {
  description = "Security group ID of the RDS instance (ECS tasks connect to port 5432)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register ECS tasks with"
  type        = string
}

variable "image_uri" {
  description = "Full container image URI (ECR URL with tag)"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the DB connection string"
  type        = string
}

variable "container_cpu" {
  description = "CPU units for the ECS task (1 vCPU = 1024)"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory in MiB for the ECS task"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of ECS service tasks"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "aspnetcore_environment" {
  description = "ASPNETCORE_ENVIRONMENT value injected into the container"
  type        = string
  default     = "Production"
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
