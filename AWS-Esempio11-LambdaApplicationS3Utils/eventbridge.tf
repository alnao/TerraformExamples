# ====================================
# EVENTBRIDGE
# ====================================

# Rule per scansione S3 schedulata (giornaliera)
resource "aws_cloudwatch_event_rule" "s3_scan_schedule" {
  name                = "${var.project_name}-s3-scan-schedule"
  description         = "Scansione S3 giornaliera"
  schedule_expression = var.s3_scan_schedule_expression
  is_enabled          = var.enable_s3_scan_schedule

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "s3_scan_schedule" {
  rule      = aws_cloudwatch_event_rule.s3_scan_schedule.name
  target_id = "LambdaS3Scan"
  arn       = aws_lambda_function.s3_scan.arn
}

# EventBridge Rule per eventi S3 (upload file)
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.project_name}-s3-object-created"
  description = "Trigger su upload file S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.main.id]
      }
    }
  })

  tags = local.common_tags
}

# Target per processamento automatico ZIP
resource "aws_cloudwatch_event_target" "s3_object_created_zip" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "ProcessZipFiles"
  arn       = aws_lambda_function.extract_zip.arn

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    input_template = <<EOF
{
  "bucket": <bucket>,
  "key": <key>
}
EOF
  }
}

resource "aws_lambda_permission" "eventbridge_extract_zip" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.extract_zip.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}
