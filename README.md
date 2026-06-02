# service-request-infra

Terraform infrastructure-as-code for the Service Request platform on AWS. Provisions the full application stack — networking, container orchestration, managed database, CDN, and object storage — across isolated `dev` and `prod` environments.

---

## Tech stack

| Layer                | Technology                              |
|----------------------|-----------------------------------------|
| IaC                  | Terraform                               |
| Cloud                | AWS                                     |
| Container runtime    | ECS (Fargate)                           |
| Container registry   | ECR                                     |
| Database             | RDS PostgreSQL                          |
| Load balancing       | Application Load Balancer (ALB)         |
| CDN / static hosting | CloudFront + S3                         |
| Networking           | VPC (public + private subnets)          |
| State backend        | S3 + DynamoDB (remote, per environment) |

---

## Architecture

```
VPC
├── Public subnets
│   └── ALB  ──────────────────────────────── HTTPS → ECS service
└── Private subnets
    ├── ECS Fargate  ←── pulls image from ECR
    └── RDS PostgreSQL

CloudFront  ──── origin ──── S3 (React SPA assets)

ECR  ──── stores .NET API Docker images
```

All modules receive `common_tags` with `Environment`, `Project`, and `ManagedBy = "terraform"`.

### Modules

| Module          | Resources                                                                                    |
|-----------------|----------------------------------------------------------------------------------------------|
| `vpc`           | VPC, public subnets, private app subnets, private DB subnets, IGW, NAT Gateway, route tables |
| `ecr`           | ECR repository for the .NET API container image                                              |
| `alb`           | Application Load Balancer, target group, listener (HTTP)                                     |
| `ecs`           | ECS cluster, Fargate task definition, ECS service, security groups, IAM roles                |
| `rds`           | RDS PostgreSQL instance, subnet group, security group, Secrets Manager secret                |
| `cloudfront-s3` | S3 bucket (private), CloudFront distribution, OAC, bucket policy                             |

### Module dependency order

```
vpc → ecr → alb + ecs + rds → cloudfront-s3
```

`ecs` depends on `alb` (target group ARN), `rds` (DB secret ARN), and `ecr` (image URI).

---

## Environments

| Environment | Var file path                        |
|-------------|--------------------------------------|
| `dev`       | `environments/dev/terraform.tfvars`  |
| `prod`      | `environments/prod/terraform.tfvars` |

Each environment has its own Terraform state key in the S3 backend.

---

## Getting started

### Prerequisites

- Terraform ≥ 1.5
- AWS CLI configured with credentials for the target account (`aws configure` or environment variables)
- An S3 bucket and DynamoDB table for Terraform remote state (see below)

### 1. Configure remote state backend

```bash
cp backend.tf.example backend.tf
```

Edit `backend.tf` and replace the placeholder values:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tf-state-bucket"
    key            = "service-request/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-tf-lock-table"
    encrypt        = true
  }
}
```

> `backend.tf` is gitignored — never commit it with real bucket/table names.

### 2. Configure variables

```bash
cp terraform.tfvars.example environments/dev/terraform.tfvars
```

Edit `environments/dev/terraform.tfvars`:

```hcl
aws_region        = "us-east-1"
environment       = "dev"
project_name      = "service-request"
db_username       = "sradmin"
db_password       = "your-strong-password-here"
db_instance_class = "db.t3.micro"
```

> Set a strong `db_password`. This value ends up in AWS Secrets Manager and is marked sensitive in Terraform.

### 3. Initialize

```bash
terraform init
```

> Run `terraform init` once per working session and whenever providers or modules change.

### 4. Plan

```bash
terraform plan -var-file=environments/dev/terraform.tfvars
```

Review the plan output before applying. No resources are created at this step.

### 5. Apply

```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

---

## Commands

| Command                                                           | Description                                                          |
|-------------------------------------------------------------------|----------------------------------------------------------------------|
| `terraform init`                                                  | Initialize providers and modules — required before any other command |
| `terraform validate`                                              | Validate configuration syntax and internal consistency               |
| `terraform plan -var-file=environments/<env>/terraform.tfvars`    | Preview changes for an environment                                   |
| `terraform apply -var-file=environments/<env>/terraform.tfvars`   | Apply changes for an environment                                     |
| `terraform destroy -var-file=environments/<env>/terraform.tfvars` | Tear down all resources for an environment                           |
| `terraform output`                                                | Print all output values after apply                                  |

---

## Outputs

After a successful `terraform apply`, the following values are available:

| Output                       | Description                                                              |
|------------------------------|--------------------------------------------------------------------------|
| `cloudfront_url`             | HTTPS URL of the CloudFront distribution serving the React SPA           |
| `alb_dns_name`               | DNS name of the Application Load Balancer (API entry point)              |
| `api_base_url`               | Base URL for the .NET API via ALB (`http://<alb_dns_name>`)              |
| `ecr_repository_url`         | ECR repository URL — use this to push the API Docker image               |
| `s3_bucket_name`             | S3 bucket hosting the React SPA static assets                            |
| `cloudfront_distribution_id` | CloudFront distribution ID — needed for cache invalidation on deploy     |
| `ecs_cluster_name`           | ECS cluster name                                                         |
| `ecs_service_name`           | ECS service name                                                         |
| `rds_endpoint`               | RDS PostgreSQL endpoint *(sensitive — not shown in terminal by default)* |

---

## Variables

| Variable            | Type   | Default           | Description                                       |
|---------------------|--------|-------------------|---------------------------------------------------|
| `aws_region`        | string | `us-east-1`       | AWS region for all resources                      |
| `environment`       | string | `dev`             | Deployment environment (`dev`, `staging`, `prod`) |
| `project_name`      | string | `service-request` | Short name used as a prefix in all resource names |
| `db_username`       | string | `sradmin`         | RDS master username                               |
| `db_password`       | string | *(required)*      | RDS master password — sensitive                   |
| `db_instance_class` | string | `db.t3.micro`     | RDS instance class                                |

---

## Project structure

```
.
├── main.tf                        # Root module — wires all child modules
├── variables.tf                   # Input variable declarations
├── outputs.tf                     # Output value declarations
├── providers.tf                   # AWS provider configuration
├── backend.tf.example             # Remote state backend template (copy to backend.tf)
├── terraform.tfvars.example       # Variable values template
├── environments/
│   ├── dev/
│   │   └── terraform.tfvars       # Dev environment variable values
│   └── prod/
│       └── terraform.tfvars       # Prod environment variable values
└── modules/
    ├── vpc/                        # Networking — VPC, subnets, IGW, NAT, route tables
    ├── ecr/                        # Container registry
    ├── alb/                        # Application Load Balancer
    ├── ecs/                        # ECS Fargate cluster, task, service
    ├── rds/                        # RDS PostgreSQL + Secrets Manager
    └── cloudfront-s3/              # S3 static hosting + CloudFront CDN
```

---

## Deploying the application

### API (after infrastructure exists)

1. Build and push the Docker image to ECR:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ecr_repository_url>
docker build -t service-request-api ../service-request-api
docker tag service-request-api:latest <ecr_repository_url>:latest
docker push <ecr_repository_url>:latest
```

2. Force a new ECS deployment to pull the latest image:

```bash
aws ecs update-service --cluster <ecs_cluster_name> --service <ecs_service_name> --force-new-deployment
```

### UI (after infrastructure exists)

1. Build the React SPA:

```bash
cd ../service-request-ui
VITE_API_BASE_URL=http://<alb_dns_name> npm run build
```

2. Sync to S3 and invalidate the CloudFront cache:

```bash
aws s3 sync dist/ s3://<s3_bucket_name>/ --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```
