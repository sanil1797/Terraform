# ============================================================
#  outputs.tf
#
#  After "terraform apply" these messages are printed
#  in your terminal telling you exactly what to do next.
# ============================================================


output "step1_what_terraform_created" {
  description = "Everything Terraform created automatically"
  value       = <<-MSG

    ✅ TERRAFORM CREATED THESE AUTOMATICALLY:
    ─────────────────────────────────────────
    S3 Bucket     : ${aws_s3_bucket.receipts.id}
    Incoming Folder: s3://${aws_s3_bucket.receipts.id}/incoming/
    DynamoDB Table : ${aws_dynamodb_table.receipts.name}
    Lambda Function: ${aws_lambda_function.receipt_processor.function_name}
    IAM Role       : ReceiptProcessingLambdaRole
    SES Identities : ${var.ses_sender_email} and ${var.ses_recipient_email}
    S3 Trigger     : Auto-calls Lambda when file uploaded to incoming/
  MSG
}


output "step2_manual_action_required" {
  description = "ONE manual step you must do before testing"
  value       = <<-MSG

    ⚠️  ONE MANUAL STEP REQUIRED — VERIFY YOUR EMAILS IN SES:
    ──────────────────────────────────────────────────────────
    Terraform registered your emails in SES but AWS needs
    you to CONFIRM you own them by clicking a link.

    1. Check your inbox for an email from:
       "Amazon Web Services <no-reply-aws@amazon.com>"
       Subject: "Amazon SES identity verification"

    2. Click the verification link inside that email

    3. Do this for BOTH emails if they are different:
       Sender    : ${var.ses_sender_email}
       Recipient : ${var.ses_recipient_email}

    WHY? AWS SES Sandbox mode requires all email addresses
    to be verified before sending/receiving emails.
    This is a one-time step only.

    ✅ Once verified → you are fully ready to test!
  MSG
}


output "step3_how_to_test" {
  description = "How to test the full pipeline"
  value       = <<-MSG

    🧪 HOW TO TEST (after email verification):
    ───────────────────────────────────────────
    Upload a receipt image to trigger the pipeline:

    aws s3 cp your-receipt.jpg s3://${aws_s3_bucket.receipts.id}/incoming/your-receipt.jpg

    Then wait 15 seconds and check:

    1. Lambda logs (did it run?):
       aws logs tail /aws/lambda/${aws_lambda_function.receipt_processor.function_name} --since 5m

    2. DynamoDB (was data extracted?):
       AWS Console → DynamoDB → Tables → ${aws_dynamodb_table.receipts.name} → Explore items

    3. Your email inbox (did notification arrive?):
       Check ${var.ses_recipient_email} for subject:
       "Receipt Processed: [vendor] - $[total]"
  MSG
}


output "step4_troubleshooting" {
  description = "Common issues and fixes"
  value       = <<-MSG

    🔧 IF SOMETHING DOESN'T WORK:
    ───────────────────────────────
    ❌ No email received?
       → Go to AWS Console → SES → Identities
       → Check if ${var.ses_sender_email} shows "Verified"
       → If not verified, click the link in your inbox

    ❌ Lambda not triggered?
       → Make sure you uploaded to incoming/ folder
       → NOT to the root of the bucket

    ❌ DynamoDB has no data?
       → Check Lambda logs for Textract errors
       → Make sure the file is a valid image (jpg/png/pdf)

    ❌ Lambda error in logs?
       → Check CloudWatch: AWS Console → CloudWatch
         → Log groups → /aws/lambda/ReceiptProcessor
  MSG
}
