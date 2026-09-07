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

data "aws_caller_identity" "current" {}

locals {
  # I tag dell'esempio sono gia' quelli richiesti dalla regola: le risorse
  # create da questo template devono risultare COMPLIANT.
  common_tags = var.tags

  bucket_name    = var.bucket_name != "" ? var.bucket_name : "${var.project_name}-config-${data.aws_caller_identity.current.account_id}"
  sns_topic_name = var.sns_topic_name != "" ? var.sns_topic_name : "${var.project_name}-non-compliant"
  rule_name      = "${var.project_name}-required-tags"

  website_bucket_name = var.website_bucket_name != "" ? var.website_bucket_name : "${var.project_name}-web-${data.aws_caller_identity.current.account_id}"
  api_name            = var.api_name != "" ? var.api_name : "${var.project_name}-api"
  lambda_name         = "${var.project_name}-list-compliance"

  # La regola nativa REQUIRED_TAGS accetta al massimo sei coppie chiave/valore,
  # nei parametri tag1Key..tag6Key e tag1Value..tag6Value.
  # I valori sono facoltativi: dove non sono indicati va bene qualsiasi valore.
  tag_keys = slice(var.required_tag_keys, 0, min(length(var.required_tag_keys), 6))

  # Parametri della regola costruiti dinamicamente: tag1Key = "project", ecc.
  parametri_chiavi = {
    for indice, chiave in local.tag_keys :
    "tag${indice + 1}Key" => chiave
  }

  # I valori ammessi si indicano come stringa separata da virgole
  parametri_valori = {
    for indice, chiave in local.tag_keys :
    "tag${indice + 1}Value" => join(",", var.allowed_tag_values[chiave])
    if lookup(var.allowed_tag_values, chiave, null) != null
  }

  parametri_regola = merge(local.parametri_chiavi, local.parametri_valori)
}
