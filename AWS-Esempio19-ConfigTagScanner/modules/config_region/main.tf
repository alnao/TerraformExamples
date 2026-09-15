# ====================================
# MODULO config_region
#
# Tutto quello che AWS Config vuole PER REGIONE: il recorder, il delivery
# channel, la regola. Il root module lo istanzia una volta per ogni regione
# in var.regions, ognuna con il suo provider.
#
# Cosa resta fuori (una volta sola, nella regione centrale): il ruolo IAM di
# Config, il bucket di consegna, l'aggregator, SNS, Lambda, API e sito.
# ====================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  s = var.settings
  # Nome regione senza trattini, per stare nei 63 caratteri dei bucket
  region_short = replace(var.region, "-", "")
}

# ---- Configuration recorder ----
# AWS ammette UN SOLO recorder per regione per account.
resource "aws_config_configuration_recorder" "main" {
  count = local.s.create_recorder ? 1 : 0

  name     = "${local.s.project_name}-recorder"
  role_arn = local.s.config_role_arn

  # Due strategie:
  #  - record_all_resources = true  -> EXCLUSION: tutto tranne excluded_resource_types
  #    (AWS::Config::ResourceCompliance, che altrimenti costa un CI per ogni
  #    valutazione, e i tipi IAM globali, che verrebbero pagati in ogni regione)
  #  - record_all_resources = false -> INCLUSION: solo recorded_resource_types
  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = local.s.record_all_resources ? null : local.s.recorded_resource_types

    dynamic "exclusion_by_resource_types" {
      for_each = local.s.record_all_resources ? [1] : []
      content {
        resource_types = local.s.excluded_resource_types
      }
    }

    dynamic "recording_strategy" {
      for_each = local.s.record_all_resources ? [1] : []
      content {
        use_only = "EXCLUSION_BY_RESOURCE_TYPES"
      }
    }
  }
}

# ---- Delivery channel ----
# Il bucket e' unico e sta nella regione centrale: Config scrive comunque
# sotto AWSLogs/<account>/Config/<regione>/, quindi le regioni non si pestano.
resource "aws_config_delivery_channel" "main" {
  count = local.s.create_recorder ? 1 : 0

  name           = "${local.s.project_name}-channel"
  s3_bucket_name = local.s.delivery_bucket_name

  snapshot_delivery_properties {
    delivery_frequency = local.s.delivery_frequency
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# ---- Accensione della registrazione ----
resource "aws_config_configuration_recorder_status" "main" {
  count = local.s.create_recorder ? 1 : 0

  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]

  # Se il recorder viene ricreato (per esempio cambia project_name) questa
  # risorsa va distrutta PRIMA del delivery channel, cioe' il recorder va
  # fermato: altrimenti DeleteDeliveryChannel fallisce con
  # LastDeliveryChannelDeleteFailedException "there is a running recorder".
  # Senza questo il provider farebbe solo un update in place dello status.
  lifecycle {
    replace_triggered_by = [aws_config_configuration_recorder.main[0].id]
  }
}

# ---- La regola nativa REQUIRED_TAGS ----
resource "aws_config_config_rule" "required_tags" {
  count = local.s.enable_native_rule ? 1 : 0

  name        = local.s.rule_name
  description = local.s.rule_description

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode(local.s.rule_parameters)

  # Senza scope la regola valuta tutti i tipi che supporta (30) fra quelli
  # registrati dal recorder; con lo scope solo i tipi elencati.
  dynamic "scope" {
    for_each = length(local.s.compliance_resource_types) > 0 ? [1] : []
    content {
      compliance_resource_types = local.s.compliance_resource_types
    }
  }

  tags = local.s.tags

  # Senza recorder attivo la regola viene creata ma resta senza valutazioni
  depends_on = [aws_config_configuration_recorder_status.main]
}

# ---- La regola CUSTOM (CloudFormation Guard) ----
# REQUIRED_TAGS conosce 30 tipi di risorsa. Per gli altri (Lambda, SNS, SQS,
# API Gateway, ECS, EKS, KMS...) Config puo' eseguire una policy Guard sul
# configuration item: niente Lambda da scrivere ne' da deployare per regione,
# la policy e' testo generato da Terraform (required_tags.guard.tpl).
resource "aws_config_config_rule" "required_tags_custom" {
  count = local.s.enable_custom_rule ? 1 : 0

  name        = local.s.custom_rule_name
  description = "${local.s.rule_description} (regola Guard per i tipi non coperti da REQUIRED_TAGS)"

  source {
    owner = "CUSTOM_POLICY"

    source_detail {
      message_type = "ConfigurationItemChangeNotification"
    }
    source_detail {
      message_type = "OversizedConfigurationItemChangeNotification"
    }

    custom_policy_details {
      policy_runtime = "guard-2.x.x"
      policy_text    = local.s.custom_rule_policy
    }
  }

  # Lo scope qui e' obbligatorio: senza, la policy girerebbe su OGNI tipo
  # registrato, compresi quelli che non possono avere tag.
  scope {
    compliance_resource_types = local.s.custom_rule_resource_types
  }

  tags = local.s.tags

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ====================================
# INOLTRO DEGLI EVENTI ALLA REGIONE CENTRALE
#
# Config pubblica "Config Rules Compliance Change" sul bus di default DELLA
# SUA regione. SNS non puo' essere bersaglio cross-region, un event bus si':
# questa regola prende i passaggi a NON_COMPLIANT e li rimanda al bus della
# regione centrale, dove una seconda regola (sns.tf nel root) li gira a SNS.
# Nella regione centrale non serve: gli eventi nascono gia' li'.
# ====================================

resource "aws_cloudwatch_event_rule" "forward_non_compliant" {
  count = local.s.enable_notification && local.s.central_bus_arn != "" ? 1 : 0

  name        = "${local.s.project_name}-forward-non-compliant"
  description = "Inoltra le risorse NON_COMPLIANT di ${var.region} alla regione centrale"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = local.s.rule_names
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = local.s.tags
}

resource "aws_cloudwatch_event_target" "central_bus" {
  count = local.s.enable_notification && local.s.central_bus_arn != "" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.forward_non_compliant[0].name
  target_id = "central-bus"
  arn       = local.s.central_bus_arn
  role_arn  = local.s.forward_role_arn
}

# ====================================
# RISORSE DI PROVA
# Due bucket per regione, identici tranne che per i tag: uno COMPLIANT e uno
# NON_COMPLIANT, cosi' l'aggregator ha qualcosa da mostrare in ogni regione.
# ====================================

resource "aws_s3_bucket" "demo_ok" {
  count = local.s.create_demo_resources ? 1 : 0

  bucket        = "${local.s.project_name}-demo-ok-${local.region_short}-${local.s.account_id}"
  force_destroy = local.s.force_destroy

  # Tutti i tag richiesti: questo bucket risultera' COMPLIANT
  tags = local.s.tags
}

resource "aws_s3_bucket" "demo_ko" {
  count = local.s.create_demo_resources ? 1 : 0

  bucket        = "${local.s.project_name}-demo-ko-${local.region_short}-${local.s.account_id}"
  force_destroy = local.s.force_destroy

  # Mancano cost, createdWith e createdBy: questo bucket risultera' NON_COMPLIANT
  tags = {
    project     = local.s.tags["project"]
    environment = local.s.tags["environment"]
  }
}
