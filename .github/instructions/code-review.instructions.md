---
applyTo: '**/*.tf'
---

# Code Review Instructions — service-request-infra

Review at **Senior Engineer** level. Enforce the patterns in `copilot-instructions.md`. Do not suggest alternatives to established patterns.

---

## 🔴 Block — Reject the PR

**Resource naming**
- Resource `name` not derived from `local.name_prefix` (`${var.project_name}-${var.environment}`). Ad-hoc names break the naming scheme.

**Tagging**
- Module call in `main.tf` missing `tags = local.common_tags`. Every module must receive `common_tags` for the `Name` merge to work.
- A resource's `tags` block does not use `merge(var.tags, { Name = "..." })`. Flat tag assignment overwrites provider `default_tags` instead of merging with them.

**Sensitive data**
- A `sensitive = true` variable (e.g., `db_password`, `db_username`) appears in an `output` block without `sensitive = true` on the output. Either mark the output sensitive or remove it entirely.
- A connection string or database password is added as a plain entry in the ECS task definition `environment` block. Sensitive values must use the `secrets` block and be pulled from Secrets Manager at container start.

**ECS container port**
- Container port is set to any value other than `8080`. The ALB target group, ALB health check, ECS SG ingress rule, and `ASPNETCORE_URLS` all reference port `8080` via `var.container_port`. Changing only one breaks the stack.

**IAM role separation**
- Application-level AWS SDK permissions (S3, SQS, SNS, DynamoDB, etc.) are attached to `task_execution_role` instead of `task_role`. The execution role is for ECS control-plane operations only (pull from ECR, read Secrets Manager, write CloudWatch logs). Runtime permissions belong on `task_role`.

**ECS service lifecycle**
- `lifecycle { ignore_changes = [task_definition, desired_count] }` is removed from `aws_ecs_service`. CI/CD manages task definition revisions and autoscaling manages desired count — Terraform must not overwrite either.

**Deployment circuit breaker**
- `deployment_circuit_breaker` block is absent, or `rollback = false`. Must be `enable = true, rollback = true`.

**ECS SG standalone pattern**
- The ECS security group is moved out of its standalone `aws_security_group.ecs` resource into another resource or the ECS service block. This standalone resource exists specifically to break the circular dependency between the `ecs` and `rds` modules. Do not reorganize it.

**Module dependency order**
- A new module references outputs from a module that appears later in the dependency chain (`vpc → ecr → alb + ecs + rds → cloudfront-s3`). Modules must only reference outputs from earlier stages.

---

## 🟡 Require — Must Be Present Before Merge

- A new module must expose all outputs consumed by `main.tf` in its own `outputs.tf`.
- A new module must accept `project_name`, `environment`, and `tags` as input variables, matching the shape of existing modules.
- Environment-specific values (instance sizes, replica counts, feature flags) must be placed in `environments/dev/terraform.tfvars` and `environments/prod/terraform.tfvars` — not hardcoded in `main.tf` or any module's `main.tf`.
- A new `aws_secretsmanager_secret` resource must set `recovery_window_in_days = 0` to match the existing convention (immediate deletion on `terraform destroy`).

---

## 🔵 Flag — Warn, Do Not Block

- `skip_final_snapshot = true` is present on an `aws_db_instance` resource and this PR targets or will be applied to the prod environment. Safe for dev, but must be explicitly reviewed before prod applies.
- `deletion_protection` is absent or set to `false` on `aws_db_instance` in a prod context.
- A new resource block is missing a `Name` tag in its `merge(var.tags, { Name = "..." })` expression.
- A hard-coded region string (e.g., `"us-east-1"`) is used instead of `data.aws_region.current.name`.
- A new variable is added without a `description` attribute.
