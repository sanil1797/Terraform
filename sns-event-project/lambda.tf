# ============================================================
#  lambda.tf
# ============================================================

# -----------------------------------------------------------
# STEP A – Zip each handler.py file individually
#
# We use "source_file" (not "source_dir") to zip just the
# single Python file. This guarantees handler.py is at the
# ROOT of the zip — which is what Lambda requires.
#
# If handler.py is inside a subfolder in the zip, Lambda
# throws: "No module named 'handler'" — which is the exact
# error we just fixed!
# -----------------------------------------------------------

# Zip the subscribe Lambda handler.py
data "archive_file" "subscribe_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/subscribe/handler.py"  # zip just this file
  output_path = "${path.module}/.build/subscribe.zip"
}

# Zip the create-event Lambda handler.py
data "archive_file" "create_event_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/create_event/handler.py"  # zip just this file
  output_path = "${path.module}/.build/create_event.zip"
}


# -----------------------------------------------------------
# STEP B – Create the Lambda functions
# -----------------------------------------------------------

# ── Lambda 1: Subscribe Function ────────────────────────────
resource "aws_lambda_function" "subscribe" {
  function_name    = "subscribeToSNSFunction"
  filename         = data.archive_file.subscribe_zip.output_path
  source_code_hash = data.archive_file.subscribe_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_subscribe_role.arn
  timeout          = 15

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.event_announcements.arn
    }
  }
}


# ── Lambda 2: Create Event Function ─────────────────────────
resource "aws_lambda_function" "create_event" {
  function_name    = "createEventFunction"
  filename         = data.archive_file.create_event_zip.output_path
  source_code_hash = data.archive_file.create_event_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_event_creation_role.arn
  timeout          = 15

  environment {
    variables = {
      BUCKET_NAME     = aws_s3_bucket.website.id
      EVENTS_FILE_KEY = "events.json"
      SNS_TOPIC_ARN   = aws_sns_topic.event_announcements.arn
    }
  }
}
