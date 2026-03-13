# --- ECR Repository ---
resource "aws_ecr_repository" "this" {
  name                 = var.pipeline_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.pipeline_name}"
  retention_in_days = 30
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "this" {
  name = "${var.pipeline_name}-cluster"
}

# --- Task Role (per-pipeline, scoped to what the code needs) ---
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
      Resource = "${var.s3_bucket_arn}/${var.s3_path_prefix}"
    }]
  })
}

# --- Task Definition ---
resource "aws_ecs_task_definition" "this" {
  family                   = var.pipeline_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
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