# ============================================================
#  lambda_src/handler.py
#
#  This is the Python code that runs inside Lambda.
#  It is triggered AUTOMATICALLY when a receipt is uploaded
#  to the incoming/ folder in S3.
#
#  FLOW:
#    S3 upload → Lambda triggered → Textract reads receipt
#    → data saved to DynamoDB → email sent via SES
#
#  WHAT EACH SECTION DOES:
#    1. lambda_handler()           → coordinates everything
#    2. process_receipt_with_textract() → reads text from receipt
#    3. store_receipt_in_dynamodb() → saves data to database
#    4. send_email_notification()  → sends email summary
# ============================================================

import json
import os
import boto3
import uuid
from datetime import datetime
import urllib.parse

# -----------------------------------------------------------
# Initialize AWS clients ONCE (outside the function)
# This is more efficient — clients are reused across calls
# instead of being recreated every time Lambda runs
# -----------------------------------------------------------
s3       = boto3.client('s3')
textract = boto3.client('textract')
dynamodb = boto3.resource('dynamodb')
ses      = boto3.client('ses')

# -----------------------------------------------------------
# Read environment variables
# These are set in lambda.tf — never hardcoded here
# -----------------------------------------------------------
DYNAMODB_TABLE      = os.environ.get('DYNAMODB_TABLE', 'Receipts')
SES_SENDER_EMAIL    = os.environ.get('SES_SENDER_EMAIL', 'your-email@example.com')
SES_RECIPIENT_EMAIL = os.environ.get('SES_RECIPIENT_EMAIL', 'recipient@example.com')


def lambda_handler(event, context):
    """
    AWS calls this function when a file is uploaded to S3.

    'event' contains info about the upload:
      - which bucket the file was uploaded to
      - the file name (key/path)
    """
    try:
        # ── Step 1: Find out which file was uploaded ──────────
        bucket = event['Records'][0]['s3']['bucket']['name']

        # URL decode the key — file names with spaces or special
        # characters get encoded in S3 events
        # e.g. "my receipt.jpg" becomes "my+receipt.jpg" in the event
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])

        print(f"Processing receipt from {bucket}/{key}")

        # ── Step 2: Verify the file actually exists ───────────
        # Sometimes S3 events fire slightly before the file is ready
        try:
            s3.head_object(Bucket=bucket, Key=key)
            print(f"Object verified: {bucket}/{key}")
        except Exception as e:
            raise Exception(f"Cannot access {key} in {bucket}: {str(e)}")

        # ── Step 3: Process with Textract ─────────────────────
        receipt_data = process_receipt_with_textract(bucket, key)

        # ── Step 4: Save to DynamoDB ──────────────────────────
        store_receipt_in_dynamodb(receipt_data, bucket, key)

        # ── Step 5: Send email notification ───────────────────
        send_email_notification(receipt_data)

        return {
            'statusCode': 200,
            'body': json.dumps('Receipt processed successfully!')
        }

    except Exception as e:
        print(f"Error processing receipt: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }


def process_receipt_with_textract(bucket, key):
    """
    Sends the receipt image to Amazon Textract.
    Textract uses AI/OCR to READ the text from the image
    and understand that it's a receipt (vendor, total, items).

    analyze_expense() is Textract's special receipt/invoice mode.
    It understands receipt structure better than plain text extraction.
    """
    try:
        print(f"Calling Textract for {bucket}/{key}")
        response = textract.analyze_expense(
            Document={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            }
        )
        print("Textract call successful")
    except Exception as e:
        print(f"Textract failed: {str(e)}")
        raise

    # Generate a unique ID for this receipt
    # uuid4() creates a random ID like "a1b2c3d4-e5f6-..."
    receipt_id = str(uuid.uuid4())

    # Default values in case Textract can't read something
    receipt_data = {
        'receipt_id': receipt_id,
        'date': datetime.now().strftime('%Y-%m-%d'),   # today's date as fallback
        'vendor': 'Unknown',
        'total': '0.00',
        'items': [],
        's3_path': f"s3://{bucket}/{key}"
    }

    # ── Parse Textract response ───────────────────────────────
    if 'ExpenseDocuments' in response and response['ExpenseDocuments']:
        expense_doc = response['ExpenseDocuments'][0]

        # Extract summary fields (TOTAL, DATE, VENDOR NAME)
        if 'SummaryFields' in expense_doc:
            for field in expense_doc['SummaryFields']:
                field_type = field.get('Type', {}).get('Text', '')
                value      = field.get('ValueDetection', {}).get('Text', '')

                if field_type == 'TOTAL':
                    receipt_data['total'] = value
                elif field_type == 'INVOICE_RECEIPT_DATE':
                    receipt_data['date'] = value
                elif field_type == 'VENDOR_NAME':
                    receipt_data['vendor'] = value

        # Extract individual line items (e.g. "Coffee - $3.50")
        if 'LineItemGroups' in expense_doc:
            for group in expense_doc['LineItemGroups']:
                if 'LineItems' in group:
                    for line_item in group['LineItems']:
                        item = {}
                        for field in line_item.get('LineItemExpenseFields', []):
                            field_type = field.get('Type', {}).get('Text', '')
                            value      = field.get('ValueDetection', {}).get('Text', '')

                            if field_type == 'ITEM':
                                item['name'] = value
                            elif field_type == 'PRICE':
                                item['price'] = value
                            elif field_type == 'QUANTITY':
                                item['quantity'] = value

                        if 'name' in item:
                            receipt_data['items'].append(item)

    print(f"Extracted data: {json.dumps(receipt_data)}")
    return receipt_data


def store_receipt_in_dynamodb(receipt_data, bucket, key):
    """
    Saves the extracted receipt data to DynamoDB.
    Each receipt becomes one "item" (row) in the table.
    """
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)

        # Format items for DynamoDB storage
        items_for_db = []
        for item in receipt_data['items']:
            items_for_db.append({
                'name':     item.get('name', 'Unknown Item'),
                'price':    item.get('price', '0.00'),
                'quantity': item.get('quantity', '1')
            })

        # The full item to insert into DynamoDB
        db_item = {
            'receipt_id':           receipt_data['receipt_id'],
            'date':                 receipt_data['date'],
            'vendor':               receipt_data['vendor'],
            'total':                receipt_data['total'],
            'items':                items_for_db,
            's3_path':              receipt_data['s3_path'],
            'processed_timestamp':  datetime.now().isoformat()
        }

        # put_item = insert or replace (upsert)
        table.put_item(Item=db_item)
        print(f"Saved to DynamoDB: {receipt_data['receipt_id']}")

    except Exception as e:
        print(f"DynamoDB error: {str(e)}")
        raise


def send_email_notification(receipt_data):
    """
    Sends an HTML email via SES with the receipt summary.
    Even if this fails, we don't stop the whole function
    (DynamoDB data is already saved — email is just a bonus).
    """
    try:
        # Build the items list for the email HTML
        items_html = ""
        for item in receipt_data['items']:
            name     = item.get('name', 'Unknown Item')
            price    = item.get('price', 'N/A')
            quantity = item.get('quantity', '1')
            items_html += f"<li>{name} - ${price} x {quantity}</li>"

        if not items_html:
            items_html = "<li>No items detected</li>"

        # HTML email body
        html_body = f"""
        <html>
        <body>
            <h2>Receipt Processing Notification</h2>
            <p><strong>Receipt ID:</strong> {receipt_data['receipt_id']}</p>
            <p><strong>Vendor:</strong> {receipt_data['vendor']}</p>
            <p><strong>Date:</strong> {receipt_data['date']}</p>
            <p><strong>Total Amount:</strong> ${receipt_data['total']}</p>
            <p><strong>S3 Location:</strong> {receipt_data['s3_path']}</p>

            <h3>Items:</h3>
            <ul>
                {items_html}
            </ul>

            <p>The receipt has been processed and stored in DynamoDB.</p>
        </body>
        </html>
        """

        ses.send_email(
            Source      = SES_SENDER_EMAIL,
            Destination = {'ToAddresses': [SES_RECIPIENT_EMAIL]},
            Message     = {
                'Subject': {
                    'Data': f"Receipt Processed: {receipt_data['vendor']} - ${receipt_data['total']}"
                },
                'Body': {
                    'Html': {'Data': html_body}
                }
            }
        )
        print(f"Email sent to {SES_RECIPIENT_EMAIL}")

    except Exception as e:
        # Don't fail the whole function if email fails
        # DynamoDB data is already saved
        print(f"Email error (non-fatal): {str(e)}")
        print("Continuing despite email error")
