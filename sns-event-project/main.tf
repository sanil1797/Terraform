# ============================================================
#  main.tf
#  This is the STARTING POINT of every Terraform project.
#  It tells Terraform:
#    1. Which version of Terraform to use
#    2. Which "plugins" (providers) to download
#    3. Which AWS region to create resources in
# ============================================================


# -----------------------------------------------------------
# BLOCK 1 – terraform {}
# This block sets up Terraform itself.
# Think of it like the "settings" block for Terraform.
# -----------------------------------------------------------
terraform {

  # Minimum Terraform version required to run this code
  required_version = ">= 1.3.0"

  # "Providers" are plugins that let Terraform talk to AWS, Azure, etc.
  # Here we need two providers:
  required_providers {

    # The AWS provider – lets Terraform create AWS resources
    aws = {
      source  = "hashicorp/aws"  # Download from HashiCorp's registry
      version = "~> 5.0"         # Use any 5.x version
    }

    # The archive provider – lets Terraform zip files (needed for Lambda)
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}


# -----------------------------------------------------------
# BLOCK 2 – provider "aws" {}
# This tells the AWS plugin WHERE to create everything.
# We use a variable (var.aws_region) so it's easy to change.
# -----------------------------------------------------------
provider "aws" {
  region = var.aws_region   # Defined in variables.tf
}
