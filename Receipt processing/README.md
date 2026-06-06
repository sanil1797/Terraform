# 🧾 Automated Receipt Processing System

A fully serverless AWS pipeline that automatically extracts data from receipt images and PDFs, stores it in a database, and sends email notifications — all triggered by a single file upload.

Built entirely with **Terraform** — one command creates the entire infrastructure.

---

## 🏗️ Architecture

```
You upload receipt
        ↓
   S3 (incoming/)
        ↓  triggers automatically
   AWS Lambda
        ↓           ↓
   Textract      DynamoDB
   (reads receipt) (stores data)
        ↓
       SES
   (emails you)
        ↓
   Your inbox ✉️
```

---

## ⚙️ Services Used

| Service | Role | Created by |
|---|---|---|
| Amazon S3 | Stores receipt images/PDFs | Terraform ✅ |
| AWS Lambda | Orchestrates the entire workflow | Terraform ✅ |
| Amazon Textract | AI/OCR — reads text from receipts | API call only |
| Amazon DynamoDB | Stores extracted receipt data | Terraform ✅ |
| Amazon SES | Sends email notifications | Terraform ✅ |
| IAM Roles | Secures access between services | Terraform ✅ |

> **Textract** needs no Terraform resource — it's an AWS API you simply call from Lambda. The only requirement is the IAM permission, which Terraform handles.

---

## 📁 Project Structure

```
receipt-processor/
├── main.tf                  # Terraform + AWS provider setup
├── variables.tf             # All settings (edit defaults here)
├── s3.tf                    # S3 bucket + incoming/ folder + trigger
├── dynamodb.tf              # Receipts table (receipt_id + date keys)
├── iam.tf                   # ReceiptProcessingLambdaRole + 5 permissions
├── lambda.tf                # Lambda function + S3 invoke permission
├── ses.tf                   # SES email identity registration
├── outputs.tf               # Prints bucket name + next steps after apply
├── .gitignore               # Excludes .terraform/, state files, zips
└── lambda_src/
    └── handler.py           # Python code: Textract → DynamoDB → SES
```

---

## 🚀 Prerequisites

| Tool | Purpose |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.3 | Infrastructure as code |
| [AWS CLI](https://aws.amazon.com/cli/) | Configured with your credentials |
| AWS account | With us-east-1 region access |

Verify setup:
```bash
terraform --version
aws sts get-caller-identity
```

---

## 🛠️ Setup & Deploy

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd receipt-processor
```

### 2. Edit `variables.tf`

Open `variables.tf` and update the three defaults:

```hcl
variable "bucket_name" {
  default = "automated-receipts-yourname-2026"  # must be globally unique
}

variable "ses_sender_email" {
  default = "your-email@gmail.com"   # must be verified in SES
}

variable "ses_recipient_email" {
  default = "your-email@gmail.com"   # can be same as sender for testing
}
```

### 3. Deploy

```bash
terraform init     # download providers
terraform plan     # preview what will be created
terraform apply    # create everything (type 'yes' when prompted)
```

### 4. Verify SES emails ⚠️

After `terraform apply`, AWS sends a verification email to both addresses.

- Check your inbox for an email from `no-reply-aws@amazon.com`
- Click the verification link
- Do this for both sender and recipient if they're different

> This is the **only manual step** in the entire project.

---

## 🧪 Testing

Upload any receipt image to trigger the pipeline:

```bash
aws s3 cp receipt.jpg s3://YOUR-BUCKET-NAME/incoming/receipt.jpg
```

Then verify each step:

```bash
# 1. Check Lambda ran
aws logs tail /aws/lambda/ReceiptProcessor --since 5m

# 2. Check DynamoDB has data
aws dynamodb scan --table-name Receipts --region us-east-1

# 3. Check your inbox for the notification email
```

Expected Lambda log output:
```
Processing receipt from bucket/incoming/receipt.jpg
Object verified
Textract call successful
Extracted data: {"vendor": "...", "total": "...", "items": [...]}
Saved to DynamoDB: <receipt-id>
Email sent to your-email@gmail.com
```

---

## 📊 DynamoDB Data Model

Each processed receipt is stored as one item:

| Attribute | Type | Example |
|---|---|---|
| `receipt_id` | String (PK) | `33c2dbbc-140c-4cec-...` |
| `date` | String (SK) | `2026-06-06` |
| `vendor` | String | `Starbucks` |
| `total` | String | `$12.50` |
| `items` | List | `[{name, price, quantity}]` |
| `s3_path` | String | `s3://bucket/incoming/receipt.jpg` |
| `processed_timestamp` | String | `2026-06-06T10:30:00` |

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| `BucketAlreadyExists` | Change `bucket_name` in `variables.tf` to something more unique |
| `No module named 'handler'` | Make sure `lambda_src/handler.py` exists and is not saved as `.txt` |
| Email not received | Check SES → Identities — both emails must show `Verified` |
| Lambda not triggered | Upload to `incoming/` folder, not the bucket root |
| No DynamoDB data | Check CloudWatch logs for Textract errors |
| Wrong region error | Run `aws configure set region us-east-1` |

---

## 🗑️ Cleanup

Remove all AWS resources with one command:

```bash
terraform destroy
```

> `force_destroy = true` is set on the S3 bucket so Terraform can delete it even if it contains receipt files.

---

## 💡 How It Works

1. **Upload** — you drop a receipt image into the `incoming/` folder in S3
2. **Trigger** — S3 automatically calls the Lambda function (no polling, no cron)
3. **OCR** — Lambda sends the image to Textract's `analyze_expense` API which understands receipt structure (vendor, date, total, line items)
4. **Store** — extracted data is written to DynamoDB as a structured item
5. **Notify** — an HTML email with the receipt summary is sent via SES
6. **Done** — the whole pipeline takes ~3 seconds end to end

---

## 📝 Notes

- Textract's `analyze_expense` API is specifically designed for receipts and invoices — it understands receipt structure rather than just extracting raw text
- SES is in **sandbox mode** by default — both sender and recipient emails must be verified. To send to unverified addresses, request production access in the SES console
- Lambda timeout is set to **3 minutes** — Textract can be slow for complex or low-quality receipt images
- The `incoming/` folder prefix on the S3 trigger means uploading to the bucket root won't trigger Lambda — only files inside `incoming/`
