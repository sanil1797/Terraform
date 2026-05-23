# ============================================================
#  quicksight.tf
#
#  Amazon QuickSight = the dashboarding/charts tool.
#  It connects to your final S3 bucket and lets you build
#  interactive charts and reports from your CSV data.
#
#  WHAT TERRAFORM CAN DO HERE:
#    ✅ Give QuickSight permission to access your S3 buckets
#    ✅ Register a QuickSight data source (pointing to S3)
#    ✅ Create a dataset from that source
#
#  WHAT YOU MUST DO MANUALLY (cannot be automated):
#    ❌ Sign up for QuickSight (requires email + billing acceptance)
#    ❌ Build charts/dashboards (drag-and-drop UI work)
#
#  NOTE: You must have signed up for QuickSight manually first
#  before running terraform apply. QuickSight signup:
#  AWS Console → QuickSight → Sign up for QuickSight
# ============================================================


# -----------------------------------------------------------
# STEP 1 – Get your AWS account ID automatically
#
# QuickSight needs your account ID to set up permissions.
# Instead of hardcoding it, we fetch it dynamically.
# -----------------------------------------------------------
data "aws_caller_identity" "current" {}


# -----------------------------------------------------------
# STEP 2 – Give QuickSight permission to read S3 buckets
#
# By default QuickSight CANNOT read your S3 data.
# This policy explicitly allows it to access all 3 buckets.
#
# "Principal": QuickSight service
# "Action": read objects from S3
# "Resource": your final data bucket (where charts come from)
# -----------------------------------------------------------
resource "aws_s3_bucket_policy" "quicksight_final_access" {
  bucket = aws_s3_bucket.final.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowQuickSightAccess"
        Effect = "Allow"
        Principal = {
          Service = "quicksight.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.final.arn,
          "${aws_s3_bucket.final.arn}/*"
        ]
      }
    ]
  })

  # Must wait for public access block to exist first
  depends_on = [aws_s3_bucket_public_access_block.final]
}


# -----------------------------------------------------------
# STEP 3 – Create a QuickSight data source
#
# A "data source" tells QuickSight WHERE the data is.
# Here we point it to our final S3 bucket.
#
# aws_quicksight_data_source connects QuickSight → S3.
# -----------------------------------------------------------
resource "aws_quicksight_data_source" "csv_datasource" {
  data_source_id = "csv-pipeline-datasource"
  name           = "CSVPipelineData"

  # Your AWS account ID (fetched automatically above)
  aws_account_id = data.aws_caller_identity.current.account_id

  # Tell QuickSight this is an S3 data source
  # and give it the manifest file location
  # The manifest file tells QuickSight exactly which file to read
  parameters {
    s3 {
      manifest_file_location {
        bucket = aws_s3_bucket.final.id
        key    = "quicksight/manifest.json"
        # We upload this manifest file in the next step
      }
    }
  }

  # QuickSight needs permission to read this data source
  # "OWNER" = full control (can edit and use)
  permission {
    actions = [
      "quicksight:UpdateDataSourcePermissions",
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:DeleteDataSource"
    ]
    # Replace with your QuickSight username
    # Format: arn:aws:quicksight:REGION:ACCOUNT_ID:user/default/USERNAME
    principal = "arn:aws:quicksight:${var.aws_region}:${data.aws_caller_identity.current.account_id}:user/default/${var.quicksight_username}"
  }

  type = "S3"

  # ssl_properties not needed for S3 (it's always encrypted)

  tags = { Project = "CSVPipeline" }
}


# -----------------------------------------------------------
# STEP 4 – Upload the QuickSight manifest file to S3
#
# A manifest file is a small JSON file that tells QuickSight:
# "The data you want to visualize is at THIS S3 location"
#
# It points to the final/ folder in the final bucket.
# QuickSight reads this manifest to find the actual CSV files.
# -----------------------------------------------------------
resource "aws_s3_object" "quicksight_manifest" {
  bucket       = aws_s3_bucket.final.id
  key          = "quicksight/manifest.json"
  content_type = "application/json"

  # The manifest points QuickSight to where the data is
  # URIPrefixes = "look at ALL files in this folder"
  content = jsonencode({
    fileLocations = [
      {
        URIPrefixes = [
          "s3://${aws_s3_bucket.final.id}/final/"
        ]
      }
    ]
    globalUploadSettings = {
      format          = "CSV"
      delimiter       = ","
      textqualifier   = "\""
      containsHeader  = "true"
    }
  })
}
