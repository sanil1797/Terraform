# ============================================================
#  lambda_src/handler.py
#
#  This is the Python code that runs inside Lambda.
#
#  WHAT IT DOES (step by step):
#
#  1. S3 uploads trigger this function automatically
#  2. It finds out WHICH file was just uploaded
#  3. It downloads that file from the raw bucket
#  4. It reads it as a CSV
#  5. It removes any rows that have empty/missing values
#  6. It saves the cleaned data as a new CSV
#  7. It uploads the cleaned CSV to the processed bucket
#
#  EXAMPLE:
#  Raw file (raw/weather-data.csv):
#    date,temp,humidity,wind
#    2024-01-01,25,80,10
#    2024-01-02,,75,8       ← missing temp! this row is removed
#    2024-01-03,22,70,12
#
#  Processed file (processed/weather-data.csv):
#    date,temp,humidity,wind
#    2024-01-01,25,80,10    ← kept
#    2024-01-03,22,70,12    ← kept
# ============================================================

import boto3   # AWS library for Python
import csv     # built-in library for reading/writing CSV files
import io      # built-in library for working with data in memory
import os      # for reading environment variables

# Create S3 client once (outside the function = reused across calls)
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    AWS calls this function automatically when a file is uploaded to S3.

    'event' contains info about what happened, including:
      - which bucket the file was uploaded to
      - what the file name (key) is
    """

    # ── Step 1: Find out which file was uploaded ──────────────
    # The event from S3 looks like:
    # { "Records": [{ "s3": { "bucket": {"name": "..."}, "object": {"key": "..."} } }] }
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key    = event['Records'][0]['s3']['object']['key']

    print(f"Processing file: s3://{bucket_name}/{file_key}")

    # Read the processed bucket name from environment variables
    # (set in lambda.tf — we never hardcode bucket names)
    processed_bucket = os.environ['PROCESSED_BUCKET_NAME']

    try:
        # ── Step 2: Download the CSV file from S3 ────────────
        response    = s3.get_object(Bucket=bucket_name, Key=file_key)
        csv_content = response['Body'].read().decode('utf-8')
        # decode('utf-8') converts raw bytes → readable text

        # ── Step 3: Read and clean the CSV ───────────────────
        processed_rows = []
        reader = csv.reader(io.StringIO(csv_content))
        # io.StringIO wraps the text so csv.reader can read it line by line

        header = next(reader)   # first row = column names (date, temp, etc.)

        for row in reader:
            # all(row) = True only if EVERY cell in the row has a value
            # If any cell is empty (""), all(row) = False → skip that row
            if all(row):
                processed_rows.append(row)

        print(f"Original rows: {reader.line_num - 1}, Clean rows: {len(processed_rows)}")

        # ── Step 4: Write the cleaned data to a new CSV ──────
        output_csv = io.StringIO()
        writer = csv.writer(output_csv)
        writer.writerow(header)          # write column names first
        writer.writerows(processed_rows) # write all clean rows

        # ── Step 5: Build the output file path ───────────────
        # We change "raw/" to "processed/" in the path
        # e.g. raw/weather-data.csv → processed/weather-data.csv
        processed_file_key = file_key.replace('raw/', 'processed/')

        # ── Step 6: Upload to the processed bucket ───────────
        s3.put_object(
            Bucket = processed_bucket,
            Key    = processed_file_key,
            Body   = output_csv.getvalue()   # the CSV text as a string
        )

        print(f"Processed file uploaded to: s3://{processed_bucket}/{processed_file_key}")

    except Exception as e:
        print(f"Error processing file: {str(e)}")
        raise   # re-raise so Lambda marks this as a failure
