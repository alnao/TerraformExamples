# ====================================
# DYNAMODB TABLES
# ====================================

# Tabella Logs
resource "aws_dynamodb_table" "logs" {
  name           = var.dynamodb_logs_table_name
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "id"
  range_key      = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "operation"
    type = "S"
  }

  global_secondary_index {
    name            = "OperationIndex"
    hash_key        = "operation"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

# Tabella Scan
resource "aws_dynamodb_table" "scan" {
  name         = local.dynamodb_scan_table_name
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "file_key"

  attribute {
    name = "file_key"
    type = "S"
  }

  attribute {
    name = "scan_date"
    type = "S"
  }

  global_secondary_index {
    name            = "ScanDateIndex"
    hash_key        = "scan_date"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}
