# ============================================================
#  api_gateway.tf
#
#  API Gateway is the "front door" for the backend.
#  The React app calls this URL to search for terms.
#
#  ENDPOINT:
#    GET /get-definition?term=AWS KMS
#    → API Gateway calls Lambda
#    → Lambda queries DynamoDB
#    → Returns definition as JSON
#
#  WHAT THIS FILE CREATES:
#    1. The REST API itself
#    2. /get-definition resource (URL path)
#    3. GET method → Lambda (proxy integration)
#    4. OPTIONS method → CORS pre-flight handler
#    5. Deploy the API so it's publicly accessible
#    6. Stage it at /dev
# ============================================================


# ── 1: REST API ───────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "cloud_dictionary" {
  name        = var.api_name
  description = "API for the Cloud Dictionary React application"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}


# ── 2: /get-definition resource ───────────────────────────────
# This is the URL path the React app calls
resource "aws_api_gateway_resource" "get_definition" {
  rest_api_id = aws_api_gateway_rest_api.cloud_dictionary.id
  parent_id   = aws_api_gateway_rest_api.cloud_dictionary.root_resource_id
  path_part   = "get-definition"   # → /get-definition
}


# ── 3a: GET method ───────────────────────────────────────────
# The React app sends GET /get-definition?term=something
resource "aws_api_gateway_method" "get_definition_get" {
  rest_api_id   = aws_api_gateway_rest_api.cloud_dictionary.id
  resource_id   = aws_api_gateway_resource.get_definition.id
  http_method   = "GET"
  authorization = "NONE"   # public endpoint — no auth needed
}

# Connect GET method → Lambda (proxy integration)
# AWS_PROXY = pass the FULL request to Lambda as-is
# Lambda returns the full response including headers
resource "aws_api_gateway_integration" "get_definition_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.cloud_dictionary.id
  resource_id             = aws_api_gateway_resource.get_definition.id
  http_method             = aws_api_gateway_method.get_definition_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.fetch_term.invoke_arn
}


# ── 3b: OPTIONS method (CORS pre-flight) ─────────────────────
# When the React app (on Amplify) calls this API (on AWS),
# the browser first sends an OPTIONS request asking
# "is this cross-origin request allowed?"
# We reply "yes" using a MOCK integration (no Lambda needed)
resource "aws_api_gateway_method" "get_definition_options" {
  rest_api_id   = aws_api_gateway_rest_api.cloud_dictionary.id
  resource_id   = aws_api_gateway_resource.get_definition.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_definition_options" {
  rest_api_id = aws_api_gateway_rest_api.cloud_dictionary.id
  resource_id = aws_api_gateway_resource.get_definition.id
  http_method = aws_api_gateway_method.get_definition_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.cloud_dictionary.id
  resource_id = aws_api_gateway_resource.get_definition.id
  http_method = aws_api_gateway_method.get_definition_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.cloud_dictionary.id
  resource_id = aws_api_gateway_resource.get_definition.id
  http_method = aws_api_gateway_method.get_definition_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.get_definition_options,
    aws_api_gateway_method_response.options_200,
  ]
}


# ── 4: Deploy the API ─────────────────────────────────────────
# Without deployment the API is just a draft — not accessible.
# Think of it like pressing "Publish"
resource "aws_api_gateway_deployment" "cloud_dictionary" {
  rest_api_id = aws_api_gateway_rest_api.cloud_dictionary.id

  # Redeploy whenever methods or integrations change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.get_definition_lambda.id,
      aws_api_gateway_integration.get_definition_options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get_definition_lambda,
    aws_api_gateway_integration.get_definition_options,
  ]
}


# ── 5: Stage ─────────────────────────────────────────────────
# Stage gives the deployment a URL prefix like /dev
# Final URL: https://abc123.execute-api.us-east-1.amazonaws.com/dev
resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.cloud_dictionary.id
  deployment_id = aws_api_gateway_deployment.cloud_dictionary.id
  stage_name    = var.api_stage_name
}
