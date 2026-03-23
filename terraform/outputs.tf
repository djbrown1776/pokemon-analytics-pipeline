output "bucket_name" {
  description = "The name of the created bucket"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "bucket_arn" {
  description = "ARN of the created bucket"
  value       = aws_s3_bucket.data_bucket.arn
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.this.repository_url
  description = "ECR repo URL — use this for docker tag and push"
}

output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "ECS cluster name — use this for run-task"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.this.arn
  description = "Task definition ARN"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.this.name
  description = "CloudWatch log group for viewing pipeline output"
}

output "execution_role_arn" {
  value       = aws_iam_role.ecs_execution_role.arn
  description = "Shared ECS execution role ARN"
}
