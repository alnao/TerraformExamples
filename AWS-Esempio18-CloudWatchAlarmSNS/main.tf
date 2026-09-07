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

  log_group_name = "/alnao/${var.project_name}/httpd/access"
  sns_topic_name = var.sns_topic_name != "" ? var.sns_topic_name : "${var.project_name}-http-errors"
  table_name     = var.table_name != "" ? var.table_name : "${var.project_name}-allarmi"
  api_name       = var.api_name != "" ? var.api_name : "${var.project_name}-api"

  lambda_sns_name  = "${var.project_name}-sns-to-dynamo"
  lambda_list_name = "${var.project_name}-list-alarms"

  # Namespace e nomi delle metriche ricavate dal log Apache
  metric_namespace      = "alnao/Esempio18"
  metric_errors         = "Http${var.monitored_status_code}Count"
  metric_requests       = "HttpRequestCount"
  metric_errors_by_path = "Http${var.monitored_status_code}CountByPath"

  api_url = aws_api_gateway_stage.main.invoke_url
}

# ====================================
# RETE
# Se non viene indicata una VPC si usa quella di default dell'account,
# cosi' l'esempio e' eseguibile senza altri prerequisiti.
# ====================================

data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id != "" ? null : true
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# Ricerca dell'AMI piu' recente di Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
