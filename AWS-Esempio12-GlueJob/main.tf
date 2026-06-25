terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = var.tags
}

resource "aws_s3_bucket" "main" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy_bucket
  tags          = local.common_tags
}

resource "aws_s3_bucket_notification" "eventbridge" {
  bucket      = aws_s3_bucket.main.id
  eventbridge = true
}

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.main.id
  key    = "${var.code_path}/etl_code.py"
  source = "${path.module}/glue/etl_code.py"
  etag   = filemd5("${path.module}/glue/etl_code.py")

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_start_process" {
  name              = "/aws/lambda/${var.project_name}-start-process"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_excel2csv" {
  name              = "/aws/lambda/${var.project_name}-excel2csv"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/vendedlogs/states/${var.step_function_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_iam_role" "glue_execution" {
  name = "${var.project_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "glue_execution" {
  name = "${var.project_name}-glue-policy"
  role = aws_iam_role.glue_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws-glue/*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_execution" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.main.arn
      }
    ]
  })
}

data "archive_file" "start_process" {
  type        = "zip"
  output_path = "${path.module}/lambda_start_process.zip"

  source {
    content  = file("${path.module}/lambda/start_process.py")
    filename = "start_process.py"
  }
}

data "archive_file" "excel2csv" {
  type        = "zip"
  output_path = "${path.module}/lambda_excel2csv.zip"

  source {
    content  = file("${path.module}/lambda/excel2csv.py")
    filename = "excel2csv.py"
  }
}

resource "aws_lambda_function" "start_process" {
  filename         = data.archive_file.start_process.output_path
  function_name    = "${var.project_name}-start-process"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "start_process.entrypoint"
  source_code_hash = data.archive_file.start_process.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = 512

  environment {
    variables = {
      FILE_PATTERN_MATCH = var.file_pattern
      STATE_MACHINE_ARN  = aws_sfn_state_machine.main.arn
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_start_process
  ]
}

resource "aws_lambda_function" "excel2csv" {
  filename         = data.archive_file.excel2csv.output_path
  function_name    = "${var.project_name}-excel2csv"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "excel2csv.lambda_handler"
  source_code_hash = data.archive_file.excel2csv.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  layers           = var.lambda_layer_arns_excel2csv

  environment {
    variables = {
      SourceBucket      = aws_s3_bucket.main.id
      SourcePath        = var.source_path
      SourceFilePattern = var.file_pattern
      DestBucket        = aws_s3_bucket.main.id
      DestPath          = var.dest_csv_path
      DestFileName      = var.csv_file_pattern
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_excel2csv
  ]
}

resource "aws_glue_job" "main" {
  name              = var.glue_job_name
  role_arn          = aws_iam_role.glue_execution.arn
  glue_version      = "3.0"
  max_retries       = 0
  worker_type       = "G.1X"
  number_of_workers = 2

  execution_property {
    max_concurrent_runs = 20
  }

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.main.id}/${aws_s3_object.glue_script.key}"
  }

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--additional-python-modules"        = "pyspark"
    "--BUCKET"                           = aws_s3_bucket.main.id
    "--SOURCE_PATH"                      = var.dest_csv_path
    "--SOURCE_FILE"                      = var.csv_file_pattern
    "--DEST_PATH"                        = var.dest_path
    "--numero_righe"                     = "0"
    "--file_name"                        = ""
  }

  tags = local.common_tags

  depends_on = [
    aws_s3_object.glue_script
  ]
}

resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-sf-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.project_name}-sf-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.excel2csv.arn
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:BatchStopJobRun",
          "glue:GetJobRuns"
        ]
        Resource = aws_glue_job.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sfn_state_machine" "main" {
  name     = var.step_function_name
  role_arn = aws_iam_role.step_functions.arn

  definition = templatefile("${path.module}/step_function_definition.json", {
    excel2csv_lambda_arn = aws_lambda_function.excel2csv.arn
    glue_job_name        = aws_glue_job.main.name
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = local.common_tags

  depends_on = [aws_cloudwatch_log_group.step_functions]
}

resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name  = "${var.project_name}-s3-upload-trigger"
  state = var.state_trigger_enabled ? "ENABLED" : "DISABLED"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.main.id]
      }
      object = {
        key = [{
          prefix = var.source_path
        }]
      }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "start_process" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "StartProcessLambda"
  arn       = aws_lambda_function.start_process.arn
}

resource "aws_lambda_permission" "eventbridge_start_process" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_process.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}
