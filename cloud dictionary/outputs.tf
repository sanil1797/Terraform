# ============================================================
#  outputs.tf
#
#  Printed in terminal after terraform apply.
#  Tells you the API URL and exact steps to complete setup.
# ============================================================


output "step1_what_terraform_created" {
  value = <<-MSG

    ✅ TERRAFORM CREATED THESE AUTOMATICALLY:
    ─────────────────────────────────────────
    DynamoDB Table   : ${aws_dynamodb_table.cloud_definitions.name}
    Lambda Function  : ${aws_lambda_function.fetch_term.function_name}
    IAM Role         : LambdaDynamoDBAccessRole
    API Gateway      : ${aws_api_gateway_rest_api.cloud_dictionary.name}
    API Stage        : ${var.api_stage_name}
  MSG
}


output "step2_api_url" {
  description = "Copy this URL into App.js in your React application"
  value       = <<-MSG

    🔗 YOUR API URL (copy this into App.js):
    ─────────────────────────────────────────
    ${aws_api_gateway_stage.dev.invoke_url}

    Full endpoint for searching terms:
    ${aws_api_gateway_stage.dev.invoke_url}/get-definition?term=AWS KMS
  MSG
}


output "step3_load_dictionary_data" {
  description = "Commands to load cloud terms into DynamoDB"
  value       = <<-MSG

    📚 LOAD DICTIONARY DATA INTO DYNAMODB:
    ────────────────────────────────────────
    Run this command to upload cloud terms (max 25 per batch):

    aws dynamodb batch-write-item \
      --request-items file://records/records-1.json \
      --region ${var.aws_region}

    If you have more records files, run for each:
    aws dynamodb batch-write-item --request-items file://records/records-2.json --region ${var.aws_region}
    aws dynamodb batch-write-item --request-items file://records/records-3.json --region ${var.aws_region}
    aws dynamodb batch-write-item --request-items file://records/records-4.json --region ${var.aws_region}

    Verify data loaded:
    aws dynamodb scan --table-name ${aws_dynamodb_table.cloud_definitions.name} --region ${var.aws_region} --select COUNT
  MSG
}


output "step4_manual_amplify_steps" {
  description = "Manual steps needed for AWS Amplify (cannot be automated)"
  value       = <<-MSG

    ⚠️  MANUAL STEPS — AWS AMPLIFY (do these in console):
    ──────────────────────────────────────────────────────
    Amplify requires GitHub OAuth which cannot be automated.
    Follow these steps:

    1. Clone the React app:
       git clone https://github.com/techwithlucy/ztc-projects-intermediate.git
       cd projects/intermediate/project4

    2. Install dependencies:
       npm install

    3. Open src/App.js and update the API URL:
       const apiUrl = '${aws_api_gateway_stage.dev.invoke_url}';

    4. Push to YOUR GitHub repo:
       git init
       git add .
       git commit -m "Add API URL"
       git remote add origin https://github.com/YOUR_USERNAME/cloud-dictionary.git
       git push -u origin main

    5. Deploy on Amplify:
       AWS Console → Amplify → Deploy an App
       → Connect GitHub → select your repo → Deploy

    ✅ Once deployed Amplify gives you a live URL!
  MSG
}


output "step5_test" {
  description = "How to test the API directly"
  value       = <<-MSG

    🧪 TEST THE API DIRECTLY (before Amplify):
    ────────────────────────────────────────────
    Search for a term:
    ${aws_api_gateway_stage.dev.invoke_url}/get-definition?term=AWS KMS

    Expected response:
    {
      "term": "AWS KMS",
      "definition": "AWS Key Management Service..."
    }

    Test Lambda directly:
    aws logs tail /aws/lambda/${aws_lambda_function.fetch_term.function_name} --since 5m
  MSG
}
