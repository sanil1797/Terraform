# ============================================================
#  s3.tf
#
#  THREE S3 buckets used in the pipeline:
#
#  1. RAW BUCKET
#     → You upload original CSV/XLSX files here
#     → Upload triggers Lambda automatically
#
#  2. PROCESSED BUCKET
#     → Lambda stores cleaned files here
#     → Glue reads from here
#
#  3. FINAL BUCKET
#     → Glue stores transformed output here
#     → QuickSight reads from here
#
#  FLOW:
#
#  Upload File
#      ↓
#  RAW BUCKET
#      ↓
#  Lambda cleans data
#      ↓
#  PROCESSED BUCKET
#      ↓
#  Glue transforms data
#      ↓
#  FINAL BUCKET
#      ↓
#  QuickSight Dashboard
# ============================================================


# ============================================================
# BUCKET 1 — RAW DATA BUCKET
# ============================================================

resource "aws_s3_bucket" "raw" {
  bucket        = var.raw_bucket_name
  force_destroy = true

  tags = {
    Project = "CSVPipeline"
    Stage   = "Raw"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# BUCKET 2 — PROCESSED DATA BUCKET
# ============================================================

resource "aws_s3_bucket" "processed" {
  bucket        = var.processed_bucket_name
  force_destroy = true

  tags = {
    Project = "CSVPipeline"
    Stage   = "Processed"
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# BUCKET 3 — FINAL DATA BUCKET
# ============================================================

resource "aws_s3_bucket" "final" {
  bucket        = var.final_bucket_name
  force_destroy = true

  tags = {
    Project = "CSVPipeline"
    Stage   = "Final"
  }
}

resource "aws_s3_bucket_public_access_block" "final" {
  bucket = aws_s3_bucket.final.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# S3 EVENT NOTIFICATION
#
# Whenever a file is uploaded into:
#
#   s3://raw-bucket/raw/
#
# Lambda automatically runs.
# ============================================================

resource "aws_s3_bucket_notification" "raw_trigger" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_preprocessor.arn

    events = [
      "s3:ObjectCreated:Put"
    ]

    filter_prefix = "raw/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_to_invoke_lambda
  ]
}


# ============================================================
# QUICKSIGHT ACCESS POLICY
#
# Allows QuickSight service to:
#   - list files in final bucket
#   - read manifest file
#   - read transformed output files
#
# Without this:
#   AccessDeniedException:
#   "Insufficient permission to access manifest file"
# ============================================================

