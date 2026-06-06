# ============================================================
#  lambda.tf
#
#  Lambda is the BRAIN of this project.
#  It runs automatically whenever a receipt is uploaded to S3.
#
#  This file does 3 things:
#    1. Zips the Python code (handler.py)
#    2. Creates the Lambda function and uploads the zip
#    3. Gives S3 PERMISSION to invoke (call) Lambda
#
#  WHAT THE LAMBDA FUNCTION DOES (step by step):
#    1. Triggered when a file appears in incoming/ in S3
#    2. Downloads the receipt image/PDF
#    3. Sends it to Textract → Textract reads the text (OCR)
#    4. Extracts: vendor name, date, total, line items
#    5. Saves all that data to DynamoDB
#    6. Sends you an email via SES with the receipt summary
# ============================================================


# -----------------------------------------------------------
# STEP 1 – Zip the Python handler file
#
# Lambda needs code as a .zip file.
# source_file = zip JUST the handler.py (not a folder)
# This puts handler.py at the ROOT of the zip —
# which is required or Lambda throws "No module named handler"
# -----------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/handler.py"
  output_path = "${path.module}/.build/receipt_processor.zip"
}


# -----------------------------------------------------------
# STEP 2 – Create the Lambda function
# -----------------------------------------------------------
resource "aws_lambda_function" "receipt_processor" {
  function_name = "ReceiptProcessor"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # source_code_hash: if handler.py changes, Terraform re-uploads

  # handler = "filename.function_name" (without .py)
  handler = "handler.lambda_handler"

  # Python version — must match what's in the guide
  runtime = "python3.9"

  # IAM role we created in iam.tf
  role = aws_iam_role.lambda_role.arn

  # 3 minutes — Textract can be slow for complex receipts
  timeout = var.lambda_timeout

  # Memory for the function
  memory_size = var.lambda_memory

  # -----------------------------------------------------------
  # Environment variables
  # These are available in Python as os.environ["KEY"]
  # We pass config here so the Python code has no hardcoded values
  # -----------------------------------------------------------
  environment {
    variables = {
      DYNAMODB_TABLE      = var.dynamodb_table_name
      SES_SENDER_EMAIL    = var.ses_sender_email
      SES_RECIPIENT_EMAIL = var.ses_recipient_email
    }
  }

  tags = {
    Project = "ReceiptProcessor"
  }
}


# -----------------------------------------------------------
# STEP 3 – Allow S3 to invoke Lambda
#
# Lambda has its own security door.
# Even though we set up the S3 trigger in s3.tf,
# we must ALSO tell Lambda: "S3 is allowed to call you"
#
# principal  = who can call Lambda (s3.amazonaws.com)
# source_arn = only THIS specific bucket can trigger it
#              (not any random S3 bucket in the world)
# -----------------------------------------------------------
resource "aws_lambda_permission" "allow_s3_to_invoke_lambda" {
  statement_id  = "AllowS3ToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receipt_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.receipts.arn
}
