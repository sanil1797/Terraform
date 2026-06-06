# ============================================================
#  s3.tf
#
#  S3 is like a Google Drive folder in the cloud.
#  We use it to store the receipt images and PDFs.
#
#  What this file does:
#    1. Creates the S3 bucket
#    2. Keeps it private (receipts are confidential)
#    3. Creates an "incoming/" folder structure
#    4. Sets up the S3 trigger to call Lambda
#       when a file is uploaded to the incoming/ folder
#
#  HOW THE TRIGGER WORKS:
#  Upload receipt → S3 detects new file → calls Lambda
#  automatically. No manual steps needed!
# ============================================================


# -----------------------------------------------------------
# STEP 1 – Create the S3 bucket
# -----------------------------------------------------------
resource "aws_s3_bucket" "receipts" {
  bucket        = var.bucket_name
  force_destroy = true # terraform destroy deletes bucket even if files exist

  tags = {
    Project = "ReceiptProcessor"
  }
}


# -----------------------------------------------------------
# STEP 2 – Keep the bucket PRIVATE
# Receipts contain sensitive financial data.
# We block ALL public access — only Lambda can read them.
# -----------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# -----------------------------------------------------------
# STEP 3 – Create the "incoming/" folder
#
# S3 doesn't have real folders — it just uses prefixes
# in file names. We create a placeholder object to represent
# the folder so it shows up in the console.
# -----------------------------------------------------------
resource "aws_s3_object" "incoming_folder" {
  bucket       = aws_s3_bucket.receipts.id
  key          = "incoming/" # trailing slash = folder
  content      = ""
  content_type = "application/x-directory"
}


# -----------------------------------------------------------
# STEP 4 – S3 Event Notification (the TRIGGER)
#
# This tells S3:
# "When ANY file is created (PUT/POST/uploaded) inside the
#  incoming/ folder, automatically call the Lambda function"
#
# Without this, Lambda would never know a receipt was uploaded.
#
# depends_on = the Lambda permission MUST exist first.
# If we create this notification before giving S3 permission
# to call Lambda, AWS will return a permission error.
# -----------------------------------------------------------
resource "aws_s3_bucket_notification" "receipt_trigger" {
  bucket = aws_s3_bucket.receipts.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.receipt_processor.arn

    # Trigger on ANY file creation event
    events = ["s3:ObjectCreated:*"]

    # Only trigger for files in the incoming/ folder
    filter_prefix = "incoming/"
  }

  depends_on = [aws_lambda_permission.allow_s3_to_invoke_lambda]
}
