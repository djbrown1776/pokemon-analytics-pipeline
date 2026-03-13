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

# Shared — one per account
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

# Per-client / per-pipeline
module "cloudtank_dev" {
  source      = "./modules/s3_tier"
  bucket_tier = "bronze"
}

# For each pipeline
module "pokemon_pipeline" {
  source             = "./modules/ecs_pipeline"
  pipeline_name      = "pokemon-pipeline"
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  s3_bucket_arn      = module.cloudtank_dev.bucket_arn
  cpu                = "256"
  memory             = "512"
  cpu_architecture   = "ARM64"
}