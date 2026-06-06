# ============================================================
#  variables.tf
#
#  All settings in one place.
#  Change the "default" values here — no other file needed.
# ============================================================


variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}


# ── DynamoDB ──────────────────────────────────────────────────
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table storing cloud terms"
  type        = string
  default     = "CloudDefinitions"
}


# ── Lambda ────────────────────────────────────────────────────
variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "FetchTermFromDynamoDB"
}


# ── API Gateway ───────────────────────────────────────────────
variable "api_name" {
  description = "Name of the API Gateway REST API"
  type        = string
  default     = "CloudDictionaryAPIGateway"
}

variable "api_stage_name" {
  description = "Deployment stage name"
  type        = string
  default     = "dev"
}
