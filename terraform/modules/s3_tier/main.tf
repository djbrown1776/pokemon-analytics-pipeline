resource "random_id" "bucket_suffix" {
  byte_length = 2
}

# BUCKET
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.ct}-${var.bucket_tier}-${random_id.bucket_suffix.hex}"

  tags = {
    Tier        = title(var.bucket_tier)
    Environment = var.environment
    Governance  = "Data-Lake"
  }
}

# LIFECYCLE POLICY
resource "aws_s3_bucket_lifecycle_configuration" "data_lifecycle" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    id     = "archive_and_cleanup"
    status = "Enabled"

    # Added empty filter to resolve the "Invalid Attribute Combination" warning
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

# ENABLE VERSIONING
resource "aws_s3_bucket_versioning" "data_versioning" {
  # Changed from bronze_bucket to data_bucket
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# BLOCK PUBLIC ACCESS
resource "aws_s3_bucket_public_access_block" "data_pab" {
  # Changed from bronze_bucket to data_bucket
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ENCRYPTION AT REST
resource "aws_s3_bucket_server_side_encryption_configuration" "data_encryption" {
  # Changed from bronze_bucket to data_bucket
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
