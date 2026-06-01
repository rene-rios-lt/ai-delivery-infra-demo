terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Uncomment and configure to use remote state:
  # backend "s3" {
  #   bucket         = "CHANGE_ME_YOUR_TF_STATE_BUCKET"
  #   key            = "service-request/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "CHANGE_ME_YOUR_TF_LOCK_TABLE"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "service-request"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "sradmin"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  ecs_sg_id         = module.ecs.ecs_sg_id
  tags              = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_app_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  rds_sg_id          = module.rds.db_sg_id
  target_group_arn   = module.alb.target_group_arn
  image_uri          = "${module.ecr.repository_url}:latest"
  db_secret_arn      = module.rds.db_secret_arn

  aspnetcore_environment = "Development"
  desired_count          = 1

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  db_subnet_ids  = module.vpc.private_db_subnet_ids
  ecs_sg_id      = module.ecs.ecs_sg_id
  db_username    = var.db_username
  db_password    = var.db_password
  instance_class = var.db_instance_class
  multi_az       = false

  tags = local.common_tags
}

module "cloudfront_s3" {
  source = "../../modules/cloudfront-s3"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

output "cloudfront_url" {
  value = "https://${module.cloudfront_s3.cloudfront_domain_name}"
}

output "api_base_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "s3_bucket_name" {
  value = module.cloudfront_s3.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.cloudfront_s3.cloudfront_distribution_id
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}
