# ============================================================
#  lambda_src/handler.py
#
#  This function runs when a user searches for a term
#  on the React website.
#
#  FLOW:
#    User types "AWS KMS" → React sends GET request
#    → API Gateway → this Lambda function
#    → DynamoDB lookup → returns definition
#
#  The "term" comes in via query string:
#    GET /get-definition?term=AWS KMS
# ============================================================

import json
import boto3
import os

# Create DynamoDB client once (reused across Lambda calls)
dynamodb = boto3.client('dynamodb')

# Read table name from environment variable
# Set in lambda.tf — never hardcoded here
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE', 'CloudDefinitions')

# CORS headers — allow the React app (on any domain) to call this API
CORS_HEADERS = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'OPTIONS,GET',
    'Access-Control-Allow-Headers': 'Content-Type',
}


def lambda_handler(event, context):
    """
    Called by API Gateway when user searches for a term.

    event['queryStringParameters']['term'] contains the search term.
    e.g. if user searches "AWS KMS", term = "AWS KMS"
    """
    try:
        # ── Step 1: Get the search term from the request ──────
        term = event['queryStringParameters']['term']
        print(f"Searching for term: {term}")

        # ── Step 2: Look up the term in DynamoDB ──────────────
        # get_item() fetches ONE specific item by its primary key
        response = dynamodb.get_item(
            TableName = DYNAMODB_TABLE,
            Key = {
                'term': {
                    'S': term   # S = String type in DynamoDB
                }
            }
        )

        # ── Step 3: Return the result ─────────────────────────
        if 'Item' in response:
            # Term found — extract the definition
            definition = response['Item']['definition']['S']
            print(f"Found: {term} → {definition[:50]}...")

            return {
                'statusCode': 200,
                'headers': CORS_HEADERS,
                'body': json.dumps({
                    'term': term,
                    'definition': definition
                })
            }
        else:
            # Term not in DynamoDB
            print(f"Term not found: {term}")
            return {
                'statusCode': 404,
                'headers': CORS_HEADERS,
                'body': json.dumps({
                    'message': 'Term not found'
                })
            }

    except KeyError:
        # No "term" in query string
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps({
                'message': 'Missing required query parameter: term'
            })
        }

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps({
                'message': f'Internal server error: {str(e)}'
            })
        }
