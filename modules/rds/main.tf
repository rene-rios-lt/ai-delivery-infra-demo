locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group for ${local.name_prefix} PostgreSQL"
  subnet_ids  = var.db_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow PostgreSQL traffic from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

# ── Secrets Manager — store DB credentials ────────────────────────────────────

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name_prefix}/rds/credentials"
  description             = "RDS credentials and connection string for ${local.name_prefix}"
  recovery_window_in_days = 0

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-db-secret"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username                       = var.db_username
    password                       = var.db_password
    engine                         = "postgres"
    host                           = aws_db_instance.this.address
    port                           = 5432
    dbname                         = var.db_name
    ConnectionStrings__DefaultConnection = "Host=${aws_db_instance.this.address};Port=5432;Database=${var.db_name};Username=${var.db_username};Password=${var.db_password}"
  })
}

# ── RDS Instance ──────────────────────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-postgres"

  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = "gp2"
  storage_encrypted    = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az               = var.multi_az
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = var.deletion_protection

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:05:00-sun:06:00"

  performance_insights_enabled = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-postgres"
  })
}
