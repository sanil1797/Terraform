# ============================================================
#  variables.tf
#  Variables are like "settings" you can change without
#  touching the main code.
#
#  Think of them like constants in programming:
#    variable "bucket_name" = "event-announcement-website"
#
#  You can override any default when running:
#    terraform apply -var="bucket_name=my-custom-name-123"
# ============================================================


# -----------------------------------------------------------
# Which AWS region to use?
# ap-south-1 = Mumbai. Change to us-east-1, eu-west-1, etc.
# -----------------------------------------------------------
variable "aws_region" {
  description = "The AWS region where all resources will be created"
  type        = string
  default     = "ap-south-1"
}


# -----------------------------------------------------------
# S3 bucket name
# IMPORTANT: Bucket names must be GLOBALLY unique across
# ALL AWS accounts in the world. Add your name or a number
# to make it unique, e.g. "event-site-john-2024"
# -----------------------------------------------------------
variable "bucket_name" {
  description = "A unique name for your S3 bucket (must be unique globally)"
  type        = string
  default     = "event-announcement-website"
}


# -----------------------------------------------------------
# SNS topic name – just a label for the notification channel
# -----------------------------------------------------------
variable "sns_topic_name" {
  description = "Name for the SNS email notification topic"
  type        = string
  default     = "EventAnnouncements"
}


# -----------------------------------------------------------
# API name – what the API Gateway will be called in AWS
# -----------------------------------------------------------
variable "api_name" {
  description = "Name for the API Gateway"
  type        = string
  default     = "EventManagementAPI"
}


# -----------------------------------------------------------
# API stage – like a "version" of your deployed API.
# "dev" means development. You could also have "prod".
# -----------------------------------------------------------
variable "api_stage_name" {
  description = "The deployment stage name for the API"
  type        = string
  default     = "dev"
}
