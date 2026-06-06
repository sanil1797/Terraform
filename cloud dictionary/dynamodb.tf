# ============================================================
#  dynamodb.tf
#
#  DynamoDB stores all the cloud terms and their definitions.
#  Think of it like a giant dictionary stored in the cloud.
#
#  TABLE STRUCTURE:
#    term        → the cloud term (e.g. "AWS KMS")   [Primary Key]
#    definition  → the meaning of that term
#
#  Why "term" as the primary key?
#  Because every term in a dictionary is unique —
#  no two entries can have the same term.
#
#  After Terraform creates the table, we load the actual
#  dictionary data using AWS CLI batch commands (see outputs.tf
#  for the exact commands to run).
# ============================================================


resource "aws_dynamodb_table" "cloud_definitions" {

  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  # PAY_PER_REQUEST = pay only when someone searches
  # No need to plan capacity in advance — scales automatically

  # Primary key = the cloud term itself
  # Every search query uses this key to find the definition
  hash_key = "term"

  attribute {
    name = "term"
    type = "S"   # S = String
  }

  # "definition" is NOT declared here because DynamoDB is
  # schema-less for non-key attributes — Lambda just reads it

  tags = {
    Project = "CloudDictionary"
  }
}
