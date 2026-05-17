# ============================================================
#  s3.tf
#
#  All 3 files come from GitHub directly.
#  For index.html, we download it from GitHub and then
#  use Terraform's replace() function to swap the two
#  placeholder strings with the real API URLs —
#  exactly like the guide says to do manually.
#
#  No extra files needed on your computer at all!
# ============================================================


# -----------------------------------------------------------
# STEP 1 – Download all 3 files from GitHub
# -----------------------------------------------------------

data "http" "index_html" {
  url = "https://raw.githubusercontent.com/techwithlucy/ztc-projects/main/projects/intermediate/project1/index.html"
}

data "http" "styles_css" {
  url = "https://raw.githubusercontent.com/techwithlucy/ztc-projects/main/projects/intermediate/project1/styles.css"
}

data "http" "events_json" {
  url = "https://raw.githubusercontent.com/techwithlucy/ztc-projects/main/projects/intermediate/project1/events.json"
}


# -----------------------------------------------------------
# STEP 2 – Replace the placeholder URLs inside index.html
#
# The GitHub index.html has these two placeholders:
#   <YOUR_CREATE_EVENT_API_ENDPOINT>
#   <YOUR_SUBSCRIBE_API_ENDPOINT>
#
# The guide says to replace them manually.
# We do the same thing automatically using replace().
#
# replace(original_text, find_this, replace_with_this)
# -----------------------------------------------------------

locals {
  # Step 1: replace the create-event placeholder
  index_with_create = replace(
    data.http.index_html.response_body,
    "<YOUR_CREATE_EVENT_API_ENDPOINT>",
    "${aws_api_gateway_stage.dev.invoke_url}/create-event"
  )

  # Step 2: replace the subscribe placeholder in the result of step 1
  index_final = replace(
    local.index_with_create,
    "<YOUR_SUBSCRIBE_API_ENDPOINT>",
    "${aws_api_gateway_stage.dev.invoke_url}/subscribe"
  )
}


# -----------------------------------------------------------
# STEP 3 – Create the S3 bucket
# -----------------------------------------------------------
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Project = "EventAnnouncement"
  }
}


# -----------------------------------------------------------
# STEP 4 – Allow public access
# -----------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


# -----------------------------------------------------------
# STEP 5 – Enable static website hosting
# -----------------------------------------------------------
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}


# -----------------------------------------------------------
# STEP 6 – Public read policy
# -----------------------------------------------------------
resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket     = aws_s3_bucket.website.id
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}


# -----------------------------------------------------------
# STEP 7 – Upload files to S3
#
# index.html → uses local.index_final (placeholders replaced)
# styles.css → straight from GitHub
# events.json → straight from GitHub
# -----------------------------------------------------------

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = local.index_final     # ← GitHub content with real URLs injected
  content_type = "text/html"
}

resource "aws_s3_object" "styles_css" {
  bucket       = aws_s3_bucket.website.id
  key          = "styles.css"
  content      = data.http.styles_css.response_body
  content_type = "text/css"
}

resource "aws_s3_object" "events_json" {
  bucket       = aws_s3_bucket.website.id
  key          = "events.json"
  content      = data.http.events_json.response_body
  content_type = "application/json"
}
