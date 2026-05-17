import json
import boto3
import os

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]

    body = event.get("body", {})
    if isinstance(body, str):
        body = json.loads(body)

    email = body.get("email") if isinstance(body, dict) else None

    if not email:
        return build_response(400, {"error": "Email not provided."})

    sns_client = boto3.client("sns")
    try:
        sns_client.subscribe(
            TopicArn = sns_topic_arn,
            Protocol = "email",
            Endpoint = email,
        )
        return build_response(200, {
            "message": "Subscription successful! Please check your email to confirm."
        })
    except Exception as e:
        print(f"Error: {str(e)}")
        return build_response(500, {"error": f"Failed to subscribe: {str(e)}"})

def build_response(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Origin":  "*",
            "Access-Control-Allow-Methods": "OPTIONS,POST",
            "Access-Control-Allow-Headers": "Content-Type",
        },
        "body": json.dumps(body_dict),
    }