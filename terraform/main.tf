terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Shared Execution Role — one per account
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "random_id" "bucket_suffix" {
  byte_length = 2
}

# Bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.ct}-${var.bucket_tier}-${random_id.bucket_suffix.hex}"

  tags = {
    Tier        = title(var.bucket_tier)
    Environment = var.environment
    Governance  = "Data-Lake"
  }
}

# Lifecyle Policy
resource "aws_s3_bucket_lifecycle_configuration" "data_lifecycle" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    id     = "archive_and_cleanup"
    status = "Enabled"

    filter {}

    transition {
      days          = var.ia_transition_days
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.expiration_days
    }
  }
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "data_versioning" {
  # Changed from bronze_bucket to data_bucket
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "data_pab" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encryption at Rest
resource "aws_s3_bucket_server_side_encryption_configuration" "data_encryption" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ECR Repository
resource "aws_ecr_repository" "this" {
  name                 = var.pipeline_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# CloudWatch Log ECS
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.pipeline_name}"
  retention_in_days = 30
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.pipeline_name}-cluster"
}

# Task Role
resource "aws_iam_role" "task_role" {
  name = "${var.pipeline_name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "${var.pipeline_name}-s3-access"
  role = aws_iam_role.task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.data_bucket.arn}/${var.s3_path_prefix}"
    }]
  })
}

# Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = var.pipeline_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = var.pipeline_name
    image     = "${aws_ecr_repository.this.repository_url}:latest"
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}
