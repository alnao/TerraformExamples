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

# ====================================
# PROVIDER
#
# Quello senza alias e' la regione centrale (var.home_region): bucket di
# consegna, aggregator, SNS, Lambda, API e sito stanno li'.
# Gli altri cinque, uno per regione controllata, servono ai moduli in
# config.tf. Terraform non sa creare provider in un ciclo, quindi sono
# scritti uno per uno; var.regions decide quali moduli vengono istanziati.
# ====================================

provider "aws" {
  region = var.home_region
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "eu_central_1"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  # I tag dell'esempio sono gia' quelli richiesti dalla regola: le risorse
  # create da questo template devono risultare COMPLIANT.
  common_tags = var.tags

  bucket_name      = var.bucket_name != "" ? var.bucket_name : "${var.project_name}-config-${data.aws_caller_identity.current.account_id}"
  sns_topic_name   = var.sns_topic_name != "" ? var.sns_topic_name : "${var.project_name}-non-compliant"
  rule_name        = "${var.project_name}-required-tags"
  custom_rule_name = "${var.project_name}-required-tags-custom"

  # Quali regole esistono: la nativa salvo custom_rule_only, la custom se
  # abilitata (custom_rule_only la implica)
  enable_native_rule = !var.custom_rule_only
  enable_custom_rule = var.enable_custom_rule || var.custom_rule_only

  # Nomi di tutte le regole attive: EventBridge, Lambda e script li cercano tutti
  rule_names = compact([
    local.enable_native_rule ? local.rule_name : "",
    local.enable_custom_rule ? local.custom_rule_name : "",
  ])

  # Con custom_rule_only la Guard copre anche i 30 tipi della nativa
  custom_rule_resource_types = var.custom_rule_only ? distinct(concat(var.custom_rule_resource_types, local.required_tags_supported_types)) : var.custom_rule_resource_types

  # Cosa registra il recorder con record_all_resources = false: esattamente
  # i tipi che le regole attive valutano, niente ENI, DHCP, SSM inventory...
  recorded_resource_types_default = distinct(concat(
    local.enable_native_rule ? local.required_tags_supported_types : [],
    local.enable_custom_rule ? local.custom_rule_resource_types : [],
  ))
  aggregator_name = "${var.project_name}-aggregator"

  website_bucket_name = var.website_bucket_name != "" ? var.website_bucket_name : "${var.project_name}-web-${data.aws_caller_identity.current.account_id}"
  api_name            = var.api_name != "" ? var.api_name : "${var.project_name}-api"
  lambda_name         = "${var.project_name}-list-compliance"

  # Bus EventBridge di default della regione centrale: le altre regioni
  # inoltrano qui gli eventi NON_COMPLIANT (vedi modulo e sns.tf)
  central_bus_arn = "arn:aws:events:${var.home_region}:${data.aws_caller_identity.current.account_id}:event-bus/default"

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

  # Varianti di ogni chiave accettate dalla regola custom: con
  # tag_keys_case_insensitive "createdWith" vale anche come "Createdwith"
  # e "CREATEDWITH"; la nativa REQUIRED_TAGS resta esatta.
  tag_key_variants = {
    for chiave in local.tag_keys :
    chiave => var.tag_keys_case_insensitive ? distinct([chiave, lower(chiave), title(chiave), upper(chiave)]) : [chiave]
  }

  # Policy Guard della regola custom, con le stesse chiavi e gli stessi
  # valori ammessi della regola nativa
  custom_rule_policy = templatefile("${path.module}/required_tags.guard.tpl", {
    chiavi         = local.tag_key_variants
    allowed_values = var.allowed_tag_values
  })
}
