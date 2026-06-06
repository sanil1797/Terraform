# ============================================================
#  iam.tf
#
#  IAM = Identity and Access Management
#
#  By default, Lambda has ZERO permissions.
#  It can't read from S3, call Textract, write to DynamoDB,
#  or send emails via SES — even though we created them.
#
#  We create ONE role: ReceiptProcessingLambdaRole
#  and attach 5 permissions to it:
#
#  1. AmazonS3ReadOnlyAccess   → Read receipt files from S3
#  2. AmazonTextractFullAccess → Send receipts to Textract for OCR
#  3. AmazonDynamoDBFullAccess → Write extracted data to DynamoDB
#  4. AmazonSESFullAccess      → Send email notifications
#  5. AWSLambdaBasicExecutionRole → Write logs to CloudWatch
#
#  Think of it like:
#    Role   = "Receipt Processing Worker" (job title)
#    Policy = list of things that worker is allowed to do
# ============================================================


# -----------------------------------------------------------
# Trust Policy
# This says: "The Lambda SERVICE is allowed to use this role"
# Without this, Lambda can't assume the role at all.
# -----------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


# -----------------------------------------------------------
# Create the Role
# -----------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name               = "ReceiptProcessingLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = "ReceiptProcessor"
  }
}


# -----------------------------------------------------------
# Permission 1: Read receipts from S3
# Lambda needs to download the uploaded receipt image/PDF
# -----------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_s3_read" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}


# -----------------------------------------------------------
# Permission 2: Use Textract
# Textract is the AI service that reads text from receipt images
# -----------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_textract" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonTextractFullAccess"
}


# -----------------------------------------------------------
# Permission 3: Write to DynamoDB
# Lambda saves extracted receipt data (vendor, total, items)
# into the DynamoDB table
# -----------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}


# -----------------------------------------------------------
# Permission 4: Send emails via SES
# After processing, Lambda emails you a summary of the receipt
# -----------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_ses" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}


# -----------------------------------------------------------
# Permission 5: Write logs to CloudWatch
# Without this you can't see what happened when Lambda runs.
# This is essential for debugging errors.
# -----------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
