# Copilot Instructions — service-request-infra

Terraform >= 1.7 infrastructure for AWS. Deploys a .NET API on ECS Fargate + a React SPA on S3/CloudFront + PostgreSQL on RDS. All resources managed through six reusable modules.

---

## Commands

```bash
# First-time setup
terraform init

# Preview changes
terraform plan -var-file=terraform.tfvars

# Apply changes
terraform apply -var-file=terraform.tfvars

# Destroy all resources
terraform destroy -var-file=terraform.tfvars
```

**Setup:**
1. Copy `terraform.tfvars.example` → `terraform.tfvars` and fill in values.
2. Copy `backend.tf.example` → `backend.tf` and configure remote state (S3 + DynamoDB).

**Per-environment var files** are in `environments/dev/` and `environments/prod/`. To target a specific environment:
```bash
terraform plan -var-file=environments/dev/terraform.tfvars
```

---

## Architecture

Module dependency order (each depends on what comes before it):

```
vpc  →  ecr  →  alb + ecs + rds  →  cloudfront-s3
```

| Module | Resources | Notes |
|---|---|---|
| `vpc` | VPC, public/private/db subnets, IGW, NAT GW, route tables | Outputs `vpc_id`, `public_subnet_ids`, `private_app_subnet_ids`, `private_db_subnet_ids` |
| `ecr` | ECR repository | Outputs `repository_url` for ECS task definition |
| `alb` | ALB, listener (80), target group, ALB security group | Outputs `alb_sg_id`, `target_group_arn`, `alb_dns_name` |
| `ecs` | ECS cluster (Fargate), task definition, service, IAM roles, CloudWatch log group, ECS security group | Container image pulled from ECR; connection string injected from Secrets Manager |
| `rds` | RDS PostgreSQL, subnet group, security group, Secrets Manager secret | DB only reachable from ECS SG; credentials stored in Secrets Manager |
| `cloudfront-s3` | S3 bucket, CloudFront distribution, OAC | Serves React SPA assets; outputs `s3_bucket_name`, `cloudfront_distribution_id` |

**Key outputs** (from `outputs.tf`):
- `cloudfront_url` — HTTPS URL of the React SPA
- `api_base_url` — ALB DNS (used as `VITE_API_BASE_URL` when building the UI)
- `ecr_repository_url` — push API container images here
- `cloudfront_distribution_id` — needed for `aws cloudfront create-invalidation` on UI deploys
- `ecs_cluster_name` + `ecs_service_name` — needed for CI/CD: `aws ecs update-service --cluster <ecs_cluster_name> --service <ecs_service_name> --force-new-deployment`
- `rds_endpoint` — sensitive; use for manual inspection only

---

## Key Conventions

**Resource naming**
All resources are named `${var.project_name}-${var.environment}-<resource>` via the `local.name_prefix` pattern defined in each module. Follow this pattern for any new resources.

**Tagging**
Tags are applied at two levels:
1. `provider "aws" { default_tags }` applies `Environment`, `Project`, `ManagedBy = "terraform"` to every resource automatically.
2. Modules merge additional `Name` tags via `merge(var.tags, { Name = "..." })`. Pass `common_tags` from `main.tf` as `tags` to every module call.

**Variables**
- `db_password` is `sensitive = true` — never output it or log it.
- Default region: `us-east-1`. Default instance class: `db.t3.micro`.

**ECS specifics**
- **Container port: `8080`**. The container listens on `8080` via `ASPNETCORE_URLS = http://+:8080`. The ALB target group, ALB health check, and ECS SG ingress rule all reference port `8080`. Use this port in any new ALB rules or health check configuration.
- **Two IAM roles** — the ECS module creates both and they serve different purposes:
  - `task_execution_role` — used by the ECS control plane to pull images from ECR, read Secrets Manager, and write CloudWatch logs. Do **not** add application-level permissions here.
  - `task_role` — assumed by the running container at runtime. Add permissions here for any AWS SDK calls the API makes (e.g., S3, SQS, SNS).
- **Plain env vars vs secrets** — the task definition uses two blocks:
  - `environment`: `ASPNETCORE_ENVIRONMENT` (default `"Production"`, controlled by `var.aspnetcore_environment`) and `ASPNETCORE_URLS` (`http://+:8080`). Add new non-sensitive config values here.
  - `secrets`: `ConnectionStrings__DefaultConnection` (pulled from Secrets Manager via `var.db_secret_arn`). Add sensitive values here — they are injected at container start, not baked into the image.
- Connection string (`ConnectionStrings__DefaultConnection`) is injected via Secrets Manager `secrets` in the task definition — not as a plain `environment` variable.
- The ECS service has `lifecycle { ignore_changes = [task_definition, desired_count] }` — Terraform will not overwrite task definition revisions or desired count set by CI/CD or autoscaling.
- Deployment circuit breaker is enabled with `rollback = true`.
- Log group: `/ecs/${project_name}-${environment}`, retention 30 days.
- Health check: `GET /health` on the container port.

**RDS specifics**
- PostgreSQL only accessible from ECS security group — no public access.
- Default database name: `servicerequestdb` (controlled by `var.db_name`). Use this name in manual `psql` connections and connection string debugging.
- `skip_final_snapshot = true` — safe for dev, review before applying to prod.
- `deletion_protection` is a variable — set to `true` in prod var files.
- Credentials stored in Secrets Manager at `${project_name}-${environment}/rds/credentials`. Secret includes both individual fields and the full `ConnectionStrings__DefaultConnection` string.
- `recovery_window_in_days = 0` on the secret — deletion is immediate with no recovery window. Keep this in mind if you ever `terraform destroy` and need to recreate.

**Security group dependency**
The ECS security group is created as a standalone resource in the `ecs` module and its ID is output as `ecs_sg_id`. This breaks the circular dependency between ECS (needs RDS SG for egress) and RDS (needs ECS SG for ingress). Do not reorganize this.

**Terraform version**
- Terraform: `>= 1.7`
- AWS provider: `~> 5.0`
- Random provider: `~> 3.5`
