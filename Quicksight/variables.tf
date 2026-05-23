# ============================================================
#  variables.tf
#
#  All the "settings" for this project in one place.
#  Change these values to customise the project.
#
#  To override any default when running:
#    terraform apply -var="raw_bucket_name=my-raw-data-123"
#
#  Or create a terraform.tfvars file (recommended):
#    raw_bucket_name       = "my-raw-data-123"
#    processed_bucket_name = "my-processed-data-123"
#    final_bucket_name     = "my-final-data-123"
# ============================================================


# AWS region – us-east-1 is required for QuickSight
variable "aws_region" {
  description = "AWS region. Keep us-east-1 for QuickSight compatibility"
  type        = string
  default     = "us-east-1"
}

# ── S3 bucket names ─────────────────────────────────────────
# IMPORTANT: All bucket names must be globally unique across
# ALL AWS accounts. Add your name/number to make them unique.
# e.g. "csv-raw-data-sanil-2026"

variable "raw_bucket_name" {
  description = "Bucket for raw CSV uploads (triggers Lambda)"
  type        = string
  default     = "csv-raw-data"
}

variable "processed_bucket_name" {
  description = "Bucket where Lambda stores cleaned CSV files"
  type        = string
  default     = "csv-processed-data"
}

variable "final_bucket_name" {
  description = "Bucket where Glue stores final transformed files"
  type        = string
  default     = "csv-final-data"
}

# ── Glue settings ────────────────────────────────────────────

variable "glue_database_name" {
  description = "Name of the Glue Data Catalog database"
  type        = string
  default     = "csv_data_pipeline_catalog"
}

variable "glue_crawler_name" {
  description = "Name of the Glue Crawler"
  type        = string
  default     = "ProcessedCSVDataCrawler"
}

variable "glue_job_name" {
  description = "Name of the Glue ETL job"
  type        = string
  default     = "CSVDataTransformation"
}

variable "quicksight_username" {
  description = "QuickSight username"
  type        = string
}
