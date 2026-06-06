# ============================================================
#  dynamodb.tf
#
#  DynamoDB is a NoSQL database — think of it like a
#  spreadsheet in the cloud where each row is a receipt.
#
#  WHY DynamoDB instead of a regular SQL database?
#    - No server to manage (fully serverless like Lambda)
#    - Handles any amount of data automatically
#    - Single-digit millisecond response time
#    - Pay only for what you use
#
#  TABLE STRUCTURE:
#  Every item (row) in the table will have:
#    receipt_id  → unique ID (e.g. "a1b2c3d4-...")  [Primary Key]
#    date        → when the receipt was issued       [Sort Key]
#    vendor      → store/restaurant name
#    total       → total amount on the receipt
#    items       → list of items bought
#    s3_path     → link back to the original image in S3
#    processed_timestamp → when Lambda processed it
#
#  Primary Key = receipt_id (each receipt is unique)
#  Sort Key    = date (lets you query by date range later)
# ============================================================


resource "aws_dynamodb_table" "receipts" {

  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  # PAY_PER_REQUEST = pay only when Lambda writes/reads data
  # No need to pre-provision capacity — scales automatically

  # Primary key (must be unique for every receipt)
  hash_key = "receipt_id" # partition key

  # Sort key (lets you query receipts by date)
  range_key = "date"

  # Define the key attributes and their types
  # S = String, N = Number, B = Binary
  attribute {
    name = "receipt_id"
    type = "S" # String
  }

  attribute {
    name = "date"
    type = "S" # String (format: YYYY-MM-DD)
  }

  # Other attributes (vendor, total, items etc.) don't need
  # to be declared here — DynamoDB is schema-less for
  # non-key attributes. Lambda just adds them automatically.

  tags = {
    Project = "ReceiptProcessor"
  }
}
