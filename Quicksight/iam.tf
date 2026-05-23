# ============================================================
#  iam.tf
#
#  IAM = Identity and Access Management
#  Think of it as a SECURITY GUARD that controls
#  which AWS service is allowed to do what.
#
#  By default, NOTHING in AWS can talk to anything else.
#  We need to explicitly grant permissions.
#
#  We create TWO roles:
#
#  ROLE 1: Lambda-S3-Glue-Role
#    → Used by the Lambda function
#    → Needs to: read from raw bucket, write to processed bucket
#    → Also needs to: write logs to CloudWatch
#
#  ROLE 2: Glue-Service-Role
#    → Used by the Glue Crawler and Glue Job
#    → Needs to: read from processed bucket, write to final bucket
#    → Also needs to: manage its own Glue operations
#
#  Think of roles like job titles:
#    Role   = "Data Cleaner" (Lambda's job title)
#    Policy = "Allowed to read raw files and write clean files"
# ============================================================


# -----------------------------------------------------------
# SHARED: Trust policy for Lambda
# This says "Lambda service is allowed to USE this role"
# Without this, Lambda can't assume the role at all
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
# SHARED: Trust policy for Glue
# Same idea but for Glue service instead of Lambda
# -----------------------------------------------------------
data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}


# ============================================================
#  ROLE 1 – Lambda-S3-Glue-Role
#  Used by the CSVPreprocessorFunction Lambda
# ============================================================

resource "aws_iam_role" "lambda_role" {
  name               = "Lambda-S3-Glue-Role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = { Project = "CSVPipeline" }
}

# Permission: Full access to S3
# Lambda needs to READ from raw bucket and WRITE to processed bucket
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Permission: Basic Lambda execution (write logs to CloudWatch)
# Without this you can't see what went wrong when Lambda fails
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



# ============================================================
#  ROLE 2 – Glue-Service-Role
#  Used by the Glue Crawler and Glue ETL Job
# ============================================================

resource "aws_iam_role" "glue_role" {
  name               = "Glue-Service-Role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json

  tags = { Project = "CSVPipeline" }
}

# Permission: Glue service operations
# Glue needs this to run crawlers, jobs, and manage the catalog
resource "aws_iam_role_policy_attachment" "glue_service_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Permission: Full S3 access
# Glue needs to READ from processed bucket and WRITE to final bucket
resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
