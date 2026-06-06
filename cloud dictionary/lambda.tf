# ============================================================
#  lambda.tf
#
#  Lambda is the backend of the dictionary app.
#  When a user searches for a term on the React website,
#  the request goes:
#    Browser → API Gateway → Lambda → DynamoDB → back
#
#  This Lambda function:
#    1. Receives the search term from the API Gateway request
#    2. Looks it up in DynamoDB
#    3. Returns the definition (or "not found")
#
#  Steps in this file:
#    A – Zip the Python handler.py file
#    B – Create the Lambda function
#    C – Allow API Gateway to call Lambda
# ============================================================


# ── A: Zip the Lambda code ────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/handler.py"
  output_path = "${path.module}/.build/fetch_term.zip"
}


# ── B: Create the Lambda function ────────────────────────────
resource "aws_lambda_function" "fetch_term" {
  function_name    = var.lambda_function_name
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # handler = "filename.function_name"
  handler = "handler.lambda_handler"
  runtime = "python3.12"
  role    = aws_iam_role.lambda_role.arn
  timeout = 10

  # Pass the DynamoDB table name as an environment variable
  # so the Python code never has a hardcoded table name
  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  tags = {
    Project = "CloudDictionary"
  }
}


# ── C: Allow API Gateway to invoke Lambda ─────────────────────
# Lambda blocks all callers by default.
# This permission says: "API Gateway is allowed to call me"
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_term.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.cloud_dictionary.execution_arn}/*/*"
}
