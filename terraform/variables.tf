variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "image-pipeline"
}

variable "thumbnail_size" {
  description = "Size of thumbnail in pixels"
  type        = number
  default     = 200

  validation {
    condition     = var.thumbnail_size > 0 && var.thumbnail_size <= 1000
    error_message = "Thumbnail size must be between 1 and 1000 pixels."
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
