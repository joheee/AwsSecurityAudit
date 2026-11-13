terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  # The org SCP only allows ap-southeast-2. IAM is global, but the API calls
  # still go through this region's endpoint config.
  region = var.region

  default_tags {
    tags = {
      project   = "aws-security-audit"
      managedby = "terraform"
    }
  }
}
