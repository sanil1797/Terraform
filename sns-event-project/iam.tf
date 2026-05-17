# ============================================================
#  iam.tf
#  IAM = Identity and Access Management
#
#  By default, Lambda functions have NO permissions.
#  They can't touch S3, SNS, or anything else.
#
#  We fix that by creating IAM "roles" and attaching
#  "policies" to them. Think of it like:
#
#    Role   = a job title (e.g. "Subscribe Lambda Worker")
#    Policy = a list of things that job title is allowed to do
#
#  We create TWO roles:
#    1. LambdaSubscribeRole     → for the Subscribe Lambda
#    2. EventCreationLambdaRole → for the Create-Event Lambda
# ============================================================


# -----------------------------------------------------------
# SHARED: Trust policy
# Both Lambda roles need this. It says:
# "AWS Lambda service is allowed to USE this role"
# Without this, Lambda can't assume the role at all.
# -----------------------------------------------------------
data "aws_iam_policy_document" "lambda_can_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]   # Allow "assuming" (using) this role
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]   # Only Lambda can use it
    }
  }
}


# ============================================================
#  ROLE 1 – LambdaSubscribeRole
#  Used by the Subscribe Lambda function.
#  Needs permission to: add emails to SNS + write logs.
# ============================================================

resource "aws_iam_role" "lambda_subscribe_role" {
  name               = "LambdaSubscribeRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_can_assume_role.json
}

# Permission 1: Full access to SNS (so it can subscribe emails)
resource "aws_iam_role_policy_attachment" "subscribe_can_use_sns" {
  role       = aws_iam_role.lambda_subscribe_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Permission 2: Write logs to CloudWatch (so we can debug issues)
resource "aws_iam_role_policy_attachment" "subscribe_can_write_logs" {
  role       = aws_iam_role.lambda_subscribe_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# ============================================================
#  ROLE 2 – EventCreationLambdaRole
#  Used by the Create-Event Lambda function.
#  Needs permission to: read/write S3 + publish to SNS + write logs.
# ============================================================

resource "aws_iam_role" "lambda_event_creation_role" {
  name               = "EventCreationLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_can_assume_role.json
}

# Permission 1: Full access to S3 (to update events.json)
resource "aws_iam_role_policy_attachment" "event_creation_can_use_s3" {
  role       = aws_iam_role.lambda_event_creation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Permission 2: Full access to SNS (to send notifications)
resource "aws_iam_role_policy_attachment" "event_creation_can_use_sns" {
  role       = aws_iam_role.lambda_event_creation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Permission 3: Write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "event_creation_can_write_logs" {
  role       = aws_iam_role.lambda_event_creation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
