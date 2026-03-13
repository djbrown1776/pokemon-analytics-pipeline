output "bucket_name" {
  description = "The name of the created bucket"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "bucket_arn" {
  description = "ARN of the created bucket"
  value       = aws_s3_bucket.data_bucket.arn
}