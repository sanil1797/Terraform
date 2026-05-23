# ============================================================
#  lambda.tf
#
#  Lambda is a serverless function — AWS runs your code
#  ONLY when it's needed (when a file is uploaded to S3).
#  You don't pay for idle time.
#
#  This file does 3 things:
#    1. Zips the Python code from lambda_src/handler.py
#    2. Creates the Lambda function and uploads the zip
#    3. Gives S3 PERMISSION to invoke (call) Lambda
#       (without this, S3 can't trigger Lambda even if we
#        set up the notification in s3.tf)
# ============================================================


# -----------------------------------------------------------
# STEP 1 – Zip the Python file
#
# Lambda requires code to be uploaded as a .zip file.
# archive_file reads handler.py and creates the zip automatically.
# source_file = zip just the single file (handler.py at root of zip)
# -----------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/handler.py"
  output_path = "${path.module}/.build/csv_preprocessor.zip"
}


# -----------------------------------------------------------
# STEP 2 – Create the Lambda function
# -----------------------------------------------------------
resource "aws_lambda_function" "csv_preprocessor" {
  function_name = "CSVPreprocessorFunction"

  # The zip file containing our Python code
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # source_code_hash: if handler.py changes, Terraform re-uploads the zip

  # "handler" = filename (without .py) . function name
  # Our file is handler.py and function is lambda_handler
  handler = "handler.lambda_handler"

  # Python version to use
  runtime = "python3.13"

  # The IAM role we created in iam.tf
  # This gives Lambda permission to access S3 and write logs
  role = aws_iam_role.lambda_role.arn

  # Max time Lambda can run before it times out
  # CSV processing shouldn't take more than 60 seconds
  timeout = 60

  # Memory allocated to Lambda (in MB)
  # More memory = faster processing but costs more
  memory_size = 256

  # Environment variables — available in Python as os.environ["KEY"]
  # We pass the processed bucket name so we don't hardcode it in the code
  environment {
    variables = {
      PROCESSED_BUCKET_NAME = aws_s3_bucket.processed.id
    }
  }

  tags = { Project = "CSVPipeline" }
}


# -----------------------------------------------------------
# STEP 3 – Allow S3 to invoke Lambda
#
# Even though we set up the S3 notification in s3.tf,
# Lambda has its own "door lock". We must explicitly say:
# "S3 service is allowed to call this Lambda function"
#
# principal     = who is allowed to call Lambda
# source_arn    = only THIS specific bucket can trigger it
#                 (not just any S3 bucket in the world)
# -----------------------------------------------------------
resource "aws_lambda_permission" "allow_s3_to_invoke_lambda" {
  statement_id  = "AllowS3ToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_preprocessor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}
