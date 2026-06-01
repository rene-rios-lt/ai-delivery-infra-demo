locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  ecs_sg_id         = module.ecs.ecs_sg_id
  tags              = local.common_tags
}

module "ecs" {
  source = "./modules/ecs"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_app_subnet_ids
  alb_sg_id            = module.alb.alb_sg_id
  rds_sg_id            = module.rds.db_sg_id
  target_group_arn     = module.alb.target_group_arn
  image_uri            = "${module.ecr.repository_url}:latest"
  db_secret_arn        = module.rds.db_secret_arn
  tags                 = local.common_tags
}

module "rds" {
  source = "./modules/rds"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  db_subnet_ids     = module.vpc.private_db_subnet_ids
  ecs_sg_id         = module.ecs.ecs_sg_id
  db_username       = var.db_username
  db_password       = var.db_password
  instance_class    = var.db_instance_class
  tags              = local.common_tags
}

module "cloudfront_s3" {
  source = "./modules/cloudfront-s3"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}
