# ============================================================
#  iam.tf
#
#  Lambda needs permission to:
#    1. Read from DynamoDB (to fetch term definitions)
#    2. Write logs to CloudWatch (for debugging)
#
#  We create ONE role: LambdaDynamoDBAccessRole
#  with exactly those two permissions — nothing more.
#
#  WHY READONLY for DynamoDB?
#  This Lambda only READS terms — it never writes.
#  Giving only the permissions needed = better security.
#  (Principle of least privilege)
# ============================================================


# Trust policy — allows Lambda service to use this role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


# Create the role
resource "aws_iam_role" "lambda_role" {
  name               = "LambdaDynamoDBAccessRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = "CloudDictionary"
  }
}


# Permission 1: Read from DynamoDB
# Lambda can GET items (search terms) but cannot write/delete
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_read" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
}


# Permission 2: Write logs to CloudWatch
# Essential for debugging — lets you see what Lambda is doing
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
