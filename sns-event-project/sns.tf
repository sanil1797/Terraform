# ============================================================
#  sns.tf
#  SNS = Simple Notification Service
#
#  Think of SNS like a mailing list:
#    - People SUBSCRIBE with their email
#    - When a new event is created, everyone on the list
#      gets an EMAIL automatically
#
#  We only need to create ONE resource here – the "topic".
#  A topic is like the mailing list itself.
#  Subscribers are added later via the Lambda function.
# ============================================================


resource "aws_sns_topic" "event_announcements" {

  # This is just the display name of the topic in AWS Console
  name = var.sns_topic_name

  tags = {
    Project = "EventAnnouncement"
  }
}


# -----------------------------------------------------------
# After Terraform runs, you can find the Topic ARN in the
# outputs (outputs.tf). You DON'T need to copy it manually —
# Terraform passes it automatically to the Lambda functions
# via environment variables.
# -----------------------------------------------------------
