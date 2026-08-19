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

  bucket_name         = var.bucket_name != "" ? var.bucket_name : "${var.project_name}-images"
  website_bucket_name = var.website_bucket_name != "" ? var.website_bucket_name : "${var.project_name}-web"
  table_name          = var.table_name != "" ? var.table_name : "${var.project_name}-images"
  api_name            = var.api_name != "" ? var.api_name : "${var.project_name}-api"

  lambda_detect_labels_name = "${var.project_name}-detect-labels"
  lambda_presigned_url_name = "${var.project_name}-presigned-url"
  lambda_list_images_name   = "${var.project_name}-list-images"
}

# ====================================
# CLOUDWATCH LOG GROUPS
# Creati esplicitamente per poter gestire la retention:
# se creati in automatico da Lambda la retention e' "Never expire"
# ====================================

resource "aws_cloudwatch_log_group" "lambda_detect_labels" {
  name              = "/aws/lambda/${local.lambda_detect_labels_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_presigned_url" {
  name              = "/aws/lambda/${local.lambda_presigned_url_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_list_images" {
  name              = "/aws/lambda/${local.lambda_list_images_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}
