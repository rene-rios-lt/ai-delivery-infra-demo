output "cloudfront_url" {
  description = "HTTPS URL of the CloudFront distribution serving the React SPA"
  value       = "https://${module.cloudfront_s3.cloudfront_domain_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL instance"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing .NET API container images"
  value       = module.ecr.repository_url
}

output "api_base_url" {
  description = "Base URL for the .NET API (via ALB)"
  value       = "http://${module.alb.alb_dns_name}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the React SPA assets"
  value       = module.cloudfront_s3.s3_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidations during deploys)"
  value       = module.cloudfront_s3.cloudfront_distribution_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}
