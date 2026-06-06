# ============================================================
#  main.tf
#
#  This is the ENTRY POINT of every Terraform project.
#  It tells Terraform:
#    1. Which version of Terraform to use
#    2. Which plugins (providers) to download
#    3. Which AWS region to create everything in
# ============================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    # AWS provider – lets Terraform create AWS resources
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Archive provider – lets Terraform zip Lambda code
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
