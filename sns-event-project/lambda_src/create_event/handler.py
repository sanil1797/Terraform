import json
import os
import boto3
from botocore.exceptions import ClientError

s3_client  = boto3.client("s3")
sns_client = boto3.client("sns")

def lambda_handler(event, context):
    bucket_name   = os.environ["BUCKET_NAME"]
    events_key    = os.environ["EVENTS_FILE_KEY"]
    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]

    try:
        new_event = json.loads(event["body"])

        response      = s3_client.get_object(Bucket=bucket_name, Key=events_key)
        existing_data = json.loads(response["Body"].read().decode("utf-8"))

        existing_data.append(new_event)

        s3_client.put_object(
            Bucket      = bucket_name,
            Key         = events_key,
            Body        = json.dumps(existing_data, indent=2),
            ContentType = "application/json",
        )

        message = (
            f"New Event: {new_event['title']}\n"
            f"Date: {new_event['date']}\n"
            f"Description: {new_event['description']}"
        )
        sns_client.publish(
            TopicArn = sns_topic_arn,
            Message  = message,
            Subject  = "New Event Announcement",
        )

        return build_response(200, {"message": "Event created successfully!"})

    except ClientError as e:
        print(f"AWS Error: {e}")
        return build_response(500, {"message": "Error processing the event"})
    except Exception as e:
        print(f"Unexpected Error: {e}")
        return build_response(500, {"message": "Unexpected error occurred"})

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