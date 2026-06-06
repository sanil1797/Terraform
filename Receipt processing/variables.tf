# ============================================================
#  variables.tf
#
#  All your settings are here in one place.
#  Just change the "default" values below once —
#  no other file needs to be touched.
#
#  After changing, run:
#    terraform apply
#  Terraform reads these defaults automatically.
# ============================================================


variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ── S3 ────────────────────────────────────────────────────────
# Change this to something unique — add your name
variable "bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
  default     = "automated-receipts-sanil-2026" # ← change this
}

# ── DynamoDB ──────────────────────────────────────────────────
variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "Receipts"
}

# ── SES Emails ────────────────────────────────────────────────
# ⚠️  Verify BOTH emails in AWS SES Console first!
# AWS Console → SES → Identities → Create Identity

variable "ses_sender_email" {
  description = "Email that SENDS the notification (must be verified in SES)"
  type        = string
  default     = "sanil1798@gmail.com" # ← change this
}

variable "ses_recipient_email" {
  description = "Email that RECEIVES the notification (must be verified in SES)"
  type        = string
  default     = "sanil1797@gmail.com" # ← can be same as sender for testing
}

# ── Lambda ────────────────────────────────────────────────────
variable "lambda_timeout" {
  description = "Max seconds Lambda can run (Textract needs time)"
  type        = number
  default     = 180
}

variable "lambda_memory" {
  description = "Memory in MB for Lambda"
  type        = number
  default     = 256
}
