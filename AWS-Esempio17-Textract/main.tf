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
  common_tags = merge(
    var.tags,
    {
      Project = var.project_name
    }
  )

  bucket_name         = var.bucket_name != "" ? var.bucket_name : "${var.project_name}-docs"
  website_bucket_name = var.website_bucket_name != "" ? var.website_bucket_name : "${var.project_name}-web"
  api_name            = var.api_name != "" ? var.api_name : "${var.project_name}-api"

  lambda_analyze_name   = "${var.project_name}-textract-analyze"
  lambda_collect_name   = "${var.project_name}-textract-collect"
  lambda_presigned_name = "${var.project_name}-presigned-url"
  lambda_list_name      = "${var.project_name}-list-documents"

  sns_topic_name = var.sns_topic_name != "" ? var.sns_topic_name : "${var.project_name}-textract-done"
}

# ====================================
# CLOUDWATCH LOG GROUPS
# Creati esplicitamente per poter gestire la retention:
# se creati in automatico da Lambda la retention e' "Never expire"
# ====================================

resource "aws_cloudwatch_log_group" "lambda_analyze" {
  name              = "/aws/lambda/${local.lambda_analyze_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_collect" {
  name              = "/aws/lambda/${local.lambda_collect_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_presigned" {
  name              = "/aws/lambda/${local.lambda_presigned_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_list" {
  name              = "/aws/lambda/${local.lambda_list_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}
