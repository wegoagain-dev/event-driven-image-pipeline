# this configures terraform and aws provider
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # use tags to help with cost tracking and resource management
  default_tags {
    tags = {
      Project     = "ImageProcessingPipeline"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
