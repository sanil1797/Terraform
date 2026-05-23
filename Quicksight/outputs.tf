# ============================================================
#  outputs.tf
#
#  After "terraform apply" these values are printed so you
#  know what was created and what to use next.
# ============================================================

output "raw_bucket_name" {
  description = "Upload your CSV files here to start the pipeline"
  value       = aws_s3_bucket.raw.id
}

output "processed_bucket_name" {
  description = "Lambda saves cleaned files here automatically"
  value       = aws_s3_bucket.processed.id
}

output "final_bucket_name" {
  description = "Glue saves transformed files here — connect QuickSight to this"
  value       = aws_s3_bucket.final.id
}

output "lambda_function_name" {
  description = "Lambda function that auto-triggers on CSV upload"
  value       = aws_lambda_function.csv_preprocessor.function_name
}

output "glue_crawler_name" {
  description = "Run this crawler in Glue Console after uploading your first CSV"
  value       = aws_glue_crawler.csv_crawler.name
}

output "glue_job_name" {
  description = "Run this job in Glue Console after the crawler finishes"
  value       = aws_glue_job.csv_transform.name
}

output "next_steps" {
  description = "What to do after terraform apply"
  value       = <<-MSG
    ✅ Infrastructure created! Follow these steps:

    1. Upload a CSV file to the raw bucket:
       Folder: s3://${aws_s3_bucket.raw.id}/raw/your-file.csv
       → Lambda triggers automatically and saves to processed bucket

    2. Run the Glue Crawler:
       AWS Console → Glue → Crawlers → ${aws_glue_crawler.csv_crawler.name} → Run
       → Discovers schema from processed bucket

    3. Run the Glue Job:
       AWS Console → Glue → Jobs → ${aws_glue_job.csv_transform.name} → Run
       → Transforms data and saves to final bucket

    4. Set up QuickSight (manual — cannot be done via Terraform):
       AWS Console → QuickSight → New Dataset → S3
       → Point to the final bucket

    NOTE: QuickSight setup must be done manually in the AWS Console.
  MSG
}
