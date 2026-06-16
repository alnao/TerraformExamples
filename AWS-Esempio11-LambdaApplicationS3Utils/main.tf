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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(
    var.tags,
    var.additional_tags,
    {
      Project = var.project_name
    }
  )
  
  dynamodb_scan_table_name = "${var.project_name}-${var.dynamodb_scan_suffix}"
}

# ====================================
# CLOUDWATCH LOG GROUPS
# ====================================

resource "aws_cloudwatch_log_group" "lambda_presigned_url" {
  name              = "/aws/lambda/${var.project_name}-presigned-url"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_extract_zip" {
  name              = "/aws/lambda/${var.project_name}-extract-zip"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_excel_to_csv" {
  name              = "/aws/lambda/${var.project_name}-excel-to-csv"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_upload_to_rds" {
  name              = "/aws/lambda/${var.project_name}-upload-to-rds"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_read_from_rds" {
  name              = "/aws/lambda/${var.project_name}-read-from-rds"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_sftp_send" {
  name              = "/aws/lambda/${var.project_name}-sftp-send"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_s3_scan" {
  name              = "/aws/lambda/${var.project_name}-s3-scan"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_list_files" {
  name              = "/aws/lambda/${var.project_name}-list-files"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_search_files" {
  name              = "/aws/lambda/${var.project_name}-search-files"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}
