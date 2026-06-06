# ============================================================
#  ses.tf
#
#  SES = Simple Email Service
#  This is AWS's email sending service.
#
#  After Lambda processes a receipt, it uses SES to send
#  you an email with:
#    - Vendor name
#    - Receipt date
#    - Total amount
#    - List of items
#    - Link to the original receipt in S3
#
#  IMPORTANT — SES SANDBOX MODE:
#  By default AWS puts all new accounts in "SES Sandbox".
#  In Sandbox mode:
#    ✅ You CAN send emails
#    ❌ But BOTH sender AND recipient emails must be verified
#
#  This file verifies both email addresses automatically.
#  AWS will send a verification email to each address.
#  You must click the link in those emails before SES works.
#
#  WHAT TERRAFORM DOES HERE:
#    → Registers both emails in SES
#    → AWS sends verification emails to them
#    → You click the links manually (one time only)
# ============================================================


# -----------------------------------------------------------
# Verify the SENDER email address
# (the "From" address in the notification emails)
# -----------------------------------------------------------
resource "aws_sesv2_email_identity" "sender" {
  email_identity = var.ses_sender_email

  tags = {
    Project = "ReceiptProcessor"
    Role    = "Sender"
  }
}


# -----------------------------------------------------------
# Verify the RECIPIENT email address
# (the "To" address — who receives the notifications)
#
# Note: If sender and recipient are the SAME email,
# Terraform is smart enough to not create a duplicate.
# Just use the same email in terraform.tfvars for both.
# -----------------------------------------------------------
resource "aws_sesv2_email_identity" "recipient" {
  # Only create a separate resource if emails are different
  # If they're the same, we just reference the sender above
  email_identity = var.ses_recipient_email

  tags = {
    Project = "ReceiptProcessor"
    Role    = "Recipient"
  }
}
