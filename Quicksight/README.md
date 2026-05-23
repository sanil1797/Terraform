# CSV Data Pipeline – Terraform

Automates the full AWS serverless data pipeline:
**S3 (raw) → Lambda → S3 (processed) → Glue → S3 (final) → QuickSight**

## 📁 Files

```
csv-pipeline/
├── main.tf          → Terraform + AWS provider setup
├── variables.tf     → All configurable settings
├── terraform.tfvars → YOUR values (bucket names etc.)
├── s3.tf            → 3 S3 buckets + S3 event trigger
├── iam.tf           → Lambda role + Glue role
├── lambda.tf        → Lambda function + S3 invoke permission
├── glue.tf          → Glue catalog + crawler + ETL job
├── outputs.tf       → Prints useful info after apply
└── lambda_src/
    └── handler.py   → Python code that cleans the CSV
```

## ▶️ Deploy

```bash
terraform init
terraform apply
```

## 📋 After Deploy (manual steps)

1. **Upload CSV** to `s3://csv-raw-data-sanil-2026/raw/your-file.csv`
   → Lambda triggers automatically

2. **Run Glue Crawler** in AWS Console
   → Discovers schema from processed bucket

3. **Run Glue Job** in AWS Console
   → Transforms and saves to final bucket

4. **Set up QuickSight** manually in AWS Console
   → QuickSight cannot be configured via Terraform

## 🗑️ Destroy

```bash
terraform destroy
```
