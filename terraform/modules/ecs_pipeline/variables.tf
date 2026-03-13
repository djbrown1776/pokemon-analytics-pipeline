variable "pipeline_name" {
  type        = string
  description = "Name for the pipeline (used for ECR repo, task def, log group)"
}

variable "execution_role_arn" {
  type        = string
  description = "ARN of the shared ECS task execution role"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket this pipeline writes to"
}

variable "s3_path_prefix" {
  type        = string
  default     = "*"
  description = "S3 path prefix for least-privilege access (e.g. 'pokemon/*')"
}

variable "cpu" {
  type    = string
  default = "256"
}

variable "memory" {
  type    = string
  default = "512"
}

variable "cpu_architecture" {
  type    = string
  default = "ARM64"
}

variable "region" {
  type    = string
  default = "us-east-1"
}