# 🚀 Event Announcement System – Terraform (Beginner Guide)

This project sets up an event website on AWS using Terraform.
Instead of clicking through the AWS Console, Terraform creates
everything automatically by reading these `.tf` files.

---

## 📁 What's in this folder?

```
terraform-beginner/
│
├── main.tf          👉 Sets up Terraform & AWS connection
├── variables.tf     👉 All the "settings" you can change
├── s3.tf            👉 Creates the website bucket & uploads files
├── sns.tf           👉 Creates the email notification topic
├── iam.tf           👉 Gives Lambda functions permission to work
├── lambda.tf        👉 Creates the two backend functions
├── api_gateway.tf   👉 Creates the API endpoints
├── outputs.tf       👉 Prints useful URLs after deployment
│
├── lambda_src/
│   ├── subscribe/handler.py      👉 Python code: handles subscriptions
│   └── create_event/handler.py   👉 Python code: handles new events
│
└── website_files/
    ├── index.html    👉 The website page
    ├── styles.css    👉 The website styling
    └── events.json   👉 Starting list of events
```

---

## 🛠️ Before you start

Make sure you have these installed:

1. **Terraform** – Download from https://developer.hashicorp.com/terraform/downloads
2. **AWS CLI** – Download from https://aws.amazon.com/cli/
3. **AWS credentials configured** – Run `aws configure` and enter your
   Access Key ID, Secret Access Key, and region.

To verify everything is ready:
```bash
terraform --version   # Should print: Terraform v1.x.x
aws sts get-caller-identity  # Should print your AWS account info
```

---

## ▶️ How to deploy (3 commands)

Open a terminal, navigate to this folder, then run:

```bash
# Step 1 – Download the AWS and archive plugins
terraform init

# Step 2 – Preview what will be created (nothing is created yet)
terraform plan -var="bucket_name=your-unique-name-here-123"

# Step 3 – Actually create everything on AWS
terraform apply -var="bucket_name=your-unique-name-here-123"
```

> ⚠️ **Replace `your-unique-name-here-123`** with any name you like.
> S3 bucket names must be unique across ALL of AWS worldwide.
> Adding your name + a number usually works, e.g. `events-john-2024`.

When asked `Do you want to perform these actions?` → type `yes` and press Enter.

---

## 🔗 After deployment – connect the website to the API

When `terraform apply` finishes, it prints something like:

```
website_url           = "http://your-bucket.s3-website.ap-south-1.amazonaws.com"
subscribe_endpoint    = "https://abc123.execute-api.ap-south-1.amazonaws.com/dev/subscribe"
create_event_endpoint = "https://abc123.execute-api.ap-south-1.amazonaws.com/dev/create-event"
```

**Do this:**
1. Open `website_files/index.html` in any text editor.
2. Find these two lines near the top of the `<script>` section:
   ```js
   const SUBSCRIBE_ENDPOINT    = "REPLACE_WITH_SUBSCRIBE_ENDPOINT";
   const CREATE_EVENT_ENDPOINT = "REPLACE_WITH_CREATE_EVENT_ENDPOINT";
   ```
3. Replace the placeholder strings with the actual URLs from the output.
4. Save the file, then run `terraform apply` again (it re-uploads the file).

Now open the `website_url` in your browser. The site is live! 🎉

---

## 🧪 Quick test with curl

```bash
# Test subscription
curl -X POST https://YOUR_API/dev/subscribe \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com"}'

# Test creating an event
curl -X POST https://YOUR_API/dev/create-event \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Event","date":"2024-12-01","description":"Hello!"}'
```

---

## 🗑️ How to delete everything

```bash
terraform destroy -var="bucket_name=your-unique-name-here-123"
```

This removes ALL AWS resources created by this project.
Type `yes` when prompted. Nothing is left behind, no hidden costs.

---

## ❓ Common beginner questions

**Q: What does `terraform init` do?**
A: Downloads the AWS plugin (like `npm install` for Node.js).

**Q: What does `terraform plan` do?**
A: Shows you what WILL be created, without actually creating anything.
   Always run this before `apply` to catch mistakes.

**Q: What is a `.tfstate` file?**
A: Terraform creates a `terraform.tfstate` file to track what it created.
   Don't delete it! Terraform needs it to know what to update or destroy.

**Q: I got "BucketAlreadyExists" error.**
A: Your bucket name is taken. Change it to something more unique.

**Q: How do I see Lambda logs?**
A: In the AWS Console → CloudWatch → Log groups → `/aws/lambda/functionName`
