# ====================================
# LAMBDA CHE LEGGE LA CONFORMITA' DA AWS CONFIG
# ====================================

data "archive_file" "list_compliance" {
  type        = "zip"
  output_path = "${path.module}/lambda_list_compliance.zip"
  source {
    content  = file("${path.module}/lambda_functions/list_compliance.py")
    filename = "list_compliance.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Sola lettura su Config: la valutazione della regola e i tag delle risorse.
# SelectResourceConfig non accetta restrizioni per risorsa, il Resource e' "*".
resource "aws_iam_role_policy" "lambda_config" {
  name = "config-read"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "config:GetComplianceDetailsByConfigRule",
        "config:DescribeConfigRules",
        "config:DescribeComplianceByConfigRule",
        "config:SelectResourceConfig",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "list_compliance" {
  function_name    = local.lambda_name
  filename         = data.archive_file.list_compliance.output_path
  source_code_hash = data.archive_file.list_compliance.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "list_compliance.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      RULE_NAME      = aws_config_config_rule.required_tags.name
      REQUIRED_TAGS  = join(",", local.tag_keys)
      ALLOWED_VALUES = jsonencode(var.allowed_tag_values)
      CORS_ORIGIN    = var.cors_allowed_origin
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = local.common_tags
}
