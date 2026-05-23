# ============================================================
#  glue.tf
#
#  AWS Glue is a managed ETL service.
#  ETL = Extract, Transform, Load
#    Extract  = read data from somewhere (processed S3 bucket)
#    Transform = change/clean/reshape the data (drop columns etc.)
#    Load     = save it somewhere else (final S3 bucket)
#
#  Think of Glue like a smart spreadsheet processor that can
#  handle millions of rows automatically.
#
#  WHY Glue AFTER Lambda?
#  Lambda is great for quick, simple cleaning (remove empty rows).
#  Glue is better for heavier work like:
#    - changing data types
#    - dropping columns
#    - joining multiple datasets
#    - handling millions of rows
#
#  This file creates 3 things:
#
#  1. Glue Database (Data Catalog)
#     → A library catalogue that knows what data exists
#     → Stores metadata: column names, data types, file location
#
#  2. Glue Crawler
#     → Scans the processed S3 bucket
#     → Automatically figures out the CSV structure
#     → Adds that info to the Data Catalog
#     → Like a librarian who reads every book and catalogues it
#
#  3. Glue Job
#     → The actual ETL worker
#     → Reads from processed bucket (using catalog info)
#     → Applies transformations (e.g. drop columns)
#     → Saves result to final bucket as compressed CSV
# ============================================================


# -----------------------------------------------------------
# PART 1 – Glue Data Catalog Database
#
# This is just a logical container (like a folder) that
# organises tables/schemas discovered by the Crawler.
# -----------------------------------------------------------
resource "aws_glue_catalog_database" "csv_catalog" {
  name        = var.glue_database_name
  description = "Data Catalog for the CSV pipeline project"
}


# -----------------------------------------------------------
# PART 2 – Glue Crawler
#
# The Crawler scans the processed S3 bucket and
# automatically creates a table in the Data Catalog
# with the correct schema (column names + data types).
#
# You run the Crawler ONCE after Lambda has processed
# at least one file. After that Glue knows the structure.
#
# schedule = "" means run on demand (manually)
# You can set a cron schedule like "cron(0 * * * ? *)"
# to run every hour automatically.
# -----------------------------------------------------------
resource "aws_glue_crawler" "csv_crawler" {
  name          = var.glue_crawler_name
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.csv_catalog.name
  description   = "Scans processed CSV files and creates schema in Data Catalog"

  # Tell the Crawler WHERE to scan (the processed bucket)
  s3_target {
    path = "s3://${aws_s3_bucket.processed.id}/processed/"
    # Only scan files in the processed/ folder
  }

  # Run on demand (not on a schedule)
  # After terraform apply, go to Glue Console → Crawlers → Run
  schedule = ""

  # Recrawl only new/changed files (more efficient)
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  # If the schema changes (e.g. new columns added), update the table
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }

  tags = { Project = "CSVPipeline" }
}


# -----------------------------------------------------------
# PART 3 – Glue ETL Job
#
# This is the actual transformation job.
# It uses PySpark (Python + Apache Spark) under the hood
# which can process huge datasets efficiently.
#
# The job script is stored IN S3 (we upload it below).
# Glue downloads and runs it when you execute the job.
#
# glue_version = "4.0" is the latest stable version
# worker_type  = "G.1X" = smallest/cheapest worker
# number_of_workers = 2 = minimum (1 driver + 1 executor)
# -----------------------------------------------------------
resource "aws_glue_job" "csv_transform" {
  name        = var.glue_job_name
  role_arn    = aws_iam_role.glue_role.arn
  description = "Transforms processed CSV and saves to final bucket"

  # Glue version 4.0 supports Python 3 and Spark 3.3
  glue_version = "4.0"

  # G.1X = 4 vCPU, 16GB RAM per worker (smallest option)
  worker_type       = "G.1X"
  number_of_workers = 2

  # Path to the PySpark script stored in S3
  # We upload this script using aws_s3_object below
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.final.id}/scripts/glue_transform.py"
    python_version  = "3"
  }

  # Pass configuration to the Glue script as arguments
  # These are available in the script as job parameters
  default_arguments = {
    "--SOURCE_DATABASE"  = var.glue_database_name
    "--SOURCE_TABLE"     = "processed"   # table name created by Crawler
    "--TARGET_S3_PATH"   = "s3://${aws_s3_bucket.final.id}/final/"
    "--job-language"     = "python"
    "--job-bookmark-option" = "job-bookmark-enable"
    # job-bookmark = Glue remembers which files it already processed
    # so it won't re-process the same file twice
  }

  tags = { Project = "CSVPipeline" }
}


# -----------------------------------------------------------
# Upload the Glue PySpark script to S3
#
# The script reads the processed CSV from Glue Catalog,
# applies transformations, and writes to the final bucket.
#
# We store the script in the final bucket under /scripts/
# -----------------------------------------------------------
resource "aws_s3_object" "glue_script" {
  bucket       = aws_s3_bucket.final.id
  key          = "scripts/glue_transform.py"
  content      = <<-PYTHON
    # ===========================================================
    #  glue_transform.py
    #
    #  This PySpark script runs inside AWS Glue.
    #  It reads the processed CSV data from the Glue Data Catalog
    #  (which the Crawler discovered), applies transformations,
    #  and writes the result to the final S3 bucket.
    #
    #  PySpark = Python + Apache Spark
    #  Spark can process huge datasets in parallel across
    #  multiple machines — much faster than plain Python.
    # ===========================================================

    import sys
    from awsglue.transforms import *
    from awsglue.utils import getResolvedOptions
    from pyspark.context import SparkContext
    from awsglue.context import GlueContext
    from awsglue.job import Job

    # Get the job arguments we passed in default_arguments
    args = getResolvedOptions(sys.argv, [
        'JOB_NAME',
        'SOURCE_DATABASE',
        'SOURCE_TABLE',
        'TARGET_S3_PATH'
    ])

    # Initialize Glue and Spark contexts
    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args['JOB_NAME'], args)

    # ── Step 1: Read data from Glue Data Catalog ────────────
    # Glue reads from the catalog table the Crawler created
    # This automatically knows the S3 location and schema
    datasource = glueContext.create_dynamic_frame.from_catalog(
        database = args['SOURCE_DATABASE'],
        table_name = args['SOURCE_TABLE']
    )

    # ── Step 2: Apply transformations ───────────────────────
    # DropNullFields removes any columns that are entirely null
    transformed = DropNullFields.apply(frame = datasource)

    # ── Step 3: Write to final S3 bucket as CSV ─────────────
    # format="csv" = save as CSV file
    # compression="gzip" = compress to save storage space
    glueContext.write_dynamic_frame.from_options(
        frame = transformed,
        connection_type = "s3",
        connection_options = {"path": args['TARGET_S3_PATH']},
        format = "csv",
        format_options = {"compression": "gzip"}
    )

    job.commit()
    print("Glue job completed successfully!")
  PYTHON
  content_type = "text/x-python"
}
