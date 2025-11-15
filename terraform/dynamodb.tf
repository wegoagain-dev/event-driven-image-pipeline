# ============================================
# DynamoDB Table
# ============================================
# creates nosql table for metadata
resource "aws_dynamodb_table" "images" {
  name         = "${local.name_prefix}-images"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing
  hash_key     = "imageId"         # this creates a primary key for the table (makes it unique)

  attribute {
    name = "imageId"
    type = "S"
  }

  attribute {
    name = "uploadDate"
    type = "S"
  }

  # GSI for querying by upload date
  global_secondary_index {
    name            = "UploadDateIndex"
    hash_key        = "uploadDate"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Enable encryption at rest
  server_side_encryption {
    enabled = true
  }
}

# Main table: Query by imageId
#   get_item(Key={'imageId': 'abc-123'})  ✅ Fast

# GSI: Query by uploadDate
#   query(IndexName='UploadDateIndex',
#         KeyConditionExpression='uploadDate = :date')  ✅ Fast
# Without GSI: Would need to scan entire table ❌ Slow & expensive
