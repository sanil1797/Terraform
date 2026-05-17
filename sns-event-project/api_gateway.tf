# ============================================================
#  api_gateway.tf
#  API Gateway = the "front door" for your backend.
#
#  The website calls two URLs:
#    POST /subscribe    → runs the Subscribe Lambda
#    POST /create-event → runs the Create Event Lambda
#
#  API Gateway receives those HTTP requests and forwards
#  them to the right Lambda function.
#
#  We also need to handle CORS. CORS is a browser security
#  rule. When a website on domain A calls an API on domain B,
#  the browser first sends an "OPTIONS" pre-flight request
#  to ask "is this allowed?". We must respond "yes".
#
#  STRUCTURE:
#    1. The REST API itself
#    2. /subscribe resource
#       a. POST method  → calls Subscribe Lambda
#       b. OPTIONS method → CORS pre-flight reply
#    3. /create-event resource
#       a. POST method  → calls Create Event Lambda
#       b. OPTIONS method → CORS pre-flight reply
#    4. Lambda permissions (allow API Gateway to call Lambda)
#    5. Deploy the API so it's publicly accessible
# ============================================================


# ============================================================
#  PART 1 – Create the REST API
# ============================================================

resource "aws_api_gateway_rest_api" "event_api" {
  name        = var.api_name
  description = "Handles subscribe and create-event requests"

  endpoint_configuration {
    types = ["REGIONAL"]   # Deploy in one region (cheaper than EDGE)
  }
}


# ============================================================
#  PART 2 – /subscribe endpoint
# ============================================================

# 2a. Create the /subscribe "resource" (the URL path)
resource "aws_api_gateway_resource" "subscribe" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  parent_id   = aws_api_gateway_rest_api.event_api.root_resource_id
  path_part   = "subscribe"    # This becomes /subscribe in the URL
}

# 2b. Create the POST method on /subscribe
# "NONE" authorization means no API key needed (public endpoint)
resource "aws_api_gateway_method" "subscribe_post" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.subscribe.id
  http_method   = "POST"
  authorization = "NONE"
}

# 2c. Connect POST /subscribe → Subscribe Lambda
# type = "AWS" means we can use a mapping template to shape the request
resource "aws_api_gateway_integration" "subscribe_post" {
  rest_api_id             = aws_api_gateway_rest_api.event_api.id
  resource_id             = aws_api_gateway_resource.subscribe.id
  http_method             = aws_api_gateway_method.subscribe_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.subscribe.invoke_arn

  # Mapping template: wraps the request body in a "body" key.
  # Our Lambda expects event["body"], so this makes it work.
  request_templates = {
    "application/json" = <<-EOT
      {
        "body": $input.json('$')
      }
    EOT
  }
}

# 2d. Define what a successful (200) response looks like
# We add CORS headers so the browser accepts the response
resource "aws_api_gateway_method_response" "subscribe_post_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# 2e. Set the actual CORS header VALUES in the response
resource "aws_api_gateway_integration_response" "subscribe_post_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
  }

  depends_on = [aws_api_gateway_integration.subscribe_post]
}

# 2f. OPTIONS /subscribe – CORS pre-flight handler
# The browser sends OPTIONS before POST. We reply with "yes, allowed".
# We use a MOCK integration (no Lambda needed – just returns 200).
resource "aws_api_gateway_method" "subscribe_options" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.subscribe.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribe_options" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  type        = "MOCK"   # Just returns a fake 200 – no Lambda needed

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "subscribe_options_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "subscribe_options_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
  }

  depends_on = [aws_api_gateway_integration.subscribe_options]
}


# ============================================================
#  PART 3 – /create-event endpoint
#  Same pattern as /subscribe, but uses Lambda Proxy (AWS_PROXY).
#  Lambda Proxy = API Gateway passes the ENTIRE request as-is
#  to Lambda. The Lambda handles everything itself.
# ============================================================

resource "aws_api_gateway_resource" "create_event" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  parent_id   = aws_api_gateway_rest_api.event_api.root_resource_id
  path_part   = "create-event"
}

resource "aws_api_gateway_method" "create_event_post" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.create_event.id
  http_method   = "POST"
  authorization = "NONE"
}

# AWS_PROXY = Lambda receives the full HTTP request and
# returns the full HTTP response (including CORS headers).
# Our Python code already adds those headers.
resource "aws_api_gateway_integration" "create_event_post" {
  rest_api_id             = aws_api_gateway_rest_api.event_api.id
  resource_id             = aws_api_gateway_resource.create_event.id
  http_method             = aws_api_gateway_method.create_event_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_event.invoke_arn
}

# OPTIONS /create-event – CORS pre-flight
resource "aws_api_gateway_method" "create_event_options" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  resource_id   = aws_api_gateway_resource.create_event.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_event_options" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.create_event.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "create_event_options_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.create_event.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "create_event_options_200" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id
  resource_id = aws_api_gateway_resource.create_event.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
  }

  depends_on = [
    aws_api_gateway_integration.create_event_options,
    aws_api_gateway_method_response.create_event_options_200,
  ]
}


# ============================================================
#  PART 4 – Allow API Gateway to invoke the Lambda functions
#
#  By default, Lambda blocks ALL callers.
#  We must explicitly say "API Gateway is allowed to call this".
# ============================================================

resource "aws_lambda_permission" "allow_apigw_to_call_subscribe" {
  statement_id  = "AllowAPIGatewayInvokeSubscribe"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscribe.function_name
  principal     = "apigateway.amazonaws.com"

  # source_arn limits which API (and which stage/method) can invoke
  source_arn = "${aws_api_gateway_rest_api.event_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_to_call_create_event" {
  statement_id  = "AllowAPIGatewayInvokeCreateEvent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_event.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.event_api.execution_arn}/*/*"
}


# ============================================================
#  PART 5 – Deploy the API
#
#  The API only becomes publicly accessible AFTER deployment.
#  Think of it like pressing "Publish" on a draft.
#
#  "triggers" forces a new deployment whenever the API
#  methods or integrations change. Without this, changes
#  to the API wouldn't automatically re-deploy.
# ============================================================

resource "aws_api_gateway_deployment" "event_api" {
  rest_api_id = aws_api_gateway_rest_api.event_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.subscribe_post.id,
      aws_api_gateway_integration.subscribe_options.id,
      aws_api_gateway_integration.create_event_post.id,
      aws_api_gateway_integration.create_event_options.id,
    ]))
  }

  # create_before_destroy: create new deployment before deleting old one
  # (avoids downtime)
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.subscribe_post,
    aws_api_gateway_integration.subscribe_options,
    aws_api_gateway_integration.create_event_post,
    aws_api_gateway_integration.create_event_options,
  ]
}

# The "stage" gives the deployment a name and a URL path prefix
# e.g. https://abc123.execute-api.ap-south-1.amazonaws.com/dev/
resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.event_api.id
  deployment_id = aws_api_gateway_deployment.event_api.id
  stage_name    = var.api_stage_name
}
