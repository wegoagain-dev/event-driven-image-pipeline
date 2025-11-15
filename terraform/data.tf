# ============================================
# Data Sources
# ============================================
# this gets my account id
data "aws_caller_identity" "current" {}

data "archive_file" "db_writer" {
  type        = "zip"
  source_dir  = "${path.module}/db_writer"
  output_path = "${path.module}/db_writer.zip"
}

data "archive_file" "image_processor" {
  type        = "zip"
  source_dir  = "${path.module}/image_processor"
  output_path = "${path.module}/image_processor.zip"
}
