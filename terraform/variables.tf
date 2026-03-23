variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ct" {
  type    = string
  default = "cloudtank"
}

variable "environment" {
  type    = string
  default = "development"
}

variable "bucket_tier" {
  type    = string
  default = "cloudtank_dev"
}

variable "ia_transition_days" {
  type    = number
  default = 30
}

variable "expiration_days" {
  type    = number
  default = 365
}

variable "pipeline_name" {
  type        = string
  description = "Name for the pipeline (used for ECR repo, task def, log group)"
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
