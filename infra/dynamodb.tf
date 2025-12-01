resource "aws_dynamodb_table" "processed_logs" {
  name         = "${local.name_prefix}-processed-logs"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "tenant_id"
  range_key = "log_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "log_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project     = var.project
    Environment = var.env
  }
}
