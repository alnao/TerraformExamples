# ====================================
# AWS CONFIG - IL MOTORE DELL'ESEMPIO
#
#   in OGNI regione (modulo config_region):
#     configuration recorder  registra com'e' fatta ogni risorsa e i suoi tag
#       -> delivery channel   consegna cronologia e snapshot sul bucket unico
#         -> config rule      valuta ogni risorsa registrata
#           -> compliance     COMPLIANT / NON_COMPLIANT, per risorsa
#
#   nella regione centrale:
#     configuration aggregator  raccoglie le valutazioni di tutte le regioni
#                               in un unico punto di lettura
#
# ⚠️ AWS ammette UN SOLO configuration recorder per regione per account:
# dove e' gia' attivo (Security Hub, Control Tower) la regione va messa in
# regions_with_existing_recorder, la regola funziona lo stesso.
# ====================================

# ---- Ruolo assunto dal servizio Config (IAM e' globale: uno per tutte le regioni) ----
resource "aws_iam_role" "config" {
  name = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = local.common_tags
}

# Politica gestita da AWS: permessi di sola lettura su tutti i servizi
# da inventariare, piu' la scrittura sul bucket di consegna.
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "delivery-bucket"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketAcl"]
        Resource = aws_s3_bucket.config.arn
      },
    ]
  })
}

# ====================================
# LE IMPOSTAZIONI COMUNI A TUTTE LE REGIONI
# Costruite una volta sola e passate tali e quali a ogni modulo: cambiare
# un parametro qui lo cambia ovunque.
# ====================================

locals {
  region_settings_base = {
    project_name    = var.project_name
    account_id      = data.aws_caller_identity.current.account_id
    tags            = local.common_tags
    config_role_arn = aws_iam_role.config.arn

    record_all_resources      = var.record_all_resources
    excluded_resource_types   = var.excluded_resource_types
    recorded_resource_types   = length(var.recorded_resource_types) > 0 ? var.recorded_resource_types : local.recorded_resource_types_default
    compliance_resource_types = var.compliance_resource_types
    delivery_bucket_name      = aws_s3_bucket.config.id
    delivery_frequency        = var.delivery_frequency

    rule_name        = local.rule_name
    rule_parameters  = local.parametri_regola
    rule_description = "Verifica che ogni risorsa abbia i tag ${join(", ", local.tag_keys)}"
    rule_names       = local.rule_names

    enable_native_rule         = local.enable_native_rule
    enable_custom_rule         = local.enable_custom_rule
    custom_rule_name           = local.custom_rule_name
    custom_rule_policy         = local.custom_rule_policy
    custom_rule_resource_types = local.custom_rule_resource_types

    enable_notification = var.enable_eventbridge_notification
    forward_role_arn    = var.enable_eventbridge_notification ? aws_iam_role.eventbridge_forward[0].arn : ""

    create_demo_resources = var.create_demo_resources
    force_destroy         = var.force_destroy
  }

  # Le uniche differenze per regione: se creare il recorder e se inoltrare
  # gli eventi (nella regione centrale non serve, sono gia' sul bus giusto)
  region_settings = {
    for r in ["us-west-2", "eu-west-1", "eu-central-1", "us-east-2", "us-east-1"] :
    r => merge(local.region_settings_base, {
      create_recorder = !contains(var.regions_with_existing_recorder, r)
      central_bus_arn = r == var.home_region ? "" : local.central_bus_arn
    })
  }
}

# ====================================
# UN MODULO PER REGIONE
# Terraform non accetta provider dinamici: un blocco per regione, con
# count che lo accende solo se la regione e' in var.regions.
# ====================================

module "region_us_west_2" {
  source = "./modules/config_region"
  count  = contains(var.regions, "us-west-2") ? 1 : 0

  providers = { aws = aws.us_west_2 }
  region    = "us-west-2"
  settings  = local.region_settings["us-west-2"]

  # Il delivery channel fallisce se la bucket policy non e' ancora in piedi
  depends_on = [aws_s3_bucket_policy.config, aws_iam_role_policy_attachment.config]
}

module "region_eu_west_1" {
  source = "./modules/config_region"
  count  = contains(var.regions, "eu-west-1") ? 1 : 0

  providers = { aws = aws.eu_west_1 }
  region    = "eu-west-1"
  settings  = local.region_settings["eu-west-1"]

  depends_on = [aws_s3_bucket_policy.config, aws_iam_role_policy_attachment.config]
}

module "region_eu_central_1" {
  source = "./modules/config_region"
  count  = contains(var.regions, "eu-central-1") ? 1 : 0

  providers = { aws = aws.eu_central_1 }
  region    = "eu-central-1"
  settings  = local.region_settings["eu-central-1"]

  depends_on = [aws_s3_bucket_policy.config, aws_iam_role_policy_attachment.config]
}

module "region_us_east_2" {
  source = "./modules/config_region"
  count  = contains(var.regions, "us-east-2") ? 1 : 0

  providers = { aws = aws.us_east_2 }
  region    = "us-east-2"
  settings  = local.region_settings["us-east-2"]

  depends_on = [aws_s3_bucket_policy.config, aws_iam_role_policy_attachment.config]
}

module "region_us_east_1" {
  source = "./modules/config_region"
  count  = contains(var.regions, "us-east-1") ? 1 : 0

  providers = { aws = aws.us_east_1 }
  region    = "us-east-1"
  settings  = local.region_settings["us-east-1"]

  depends_on = [aws_s3_bucket_policy.config, aws_iam_role_policy_attachment.config]
}

# Mappa regione => output del modulo, solo per le regioni attive
locals {
  region_modules = merge(
    { for m in module.region_us_west_2 : m.region => m },
    { for m in module.region_eu_west_1 : m.region => m },
    { for m in module.region_eu_central_1 : m.region => m },
    { for m in module.region_us_east_2 : m.region => m },
    { for m in module.region_us_east_1 : m.region => m },
  )
}

# ====================================
# CONFIGURATION AGGREGATOR
#
# Config tiene le valutazioni regione per regione. L'aggregator, nella
# regione centrale, le copia tutte in una vista unica interrogabile con le
# API *Aggregate* (GetAggregateComplianceDetailsByConfigRule,
# SelectAggregateResourceConfig): e' quella che leggono Lambda e script.
# Nello stesso account non serve nessuna autorizzazione, e' gratuito.
# ====================================

resource "aws_config_configuration_aggregator" "main" {
  name = local.aggregator_name

  account_aggregation_source {
    account_ids = [data.aws_caller_identity.current.account_id]
    regions     = var.regions
  }

  tags = local.common_tags
}
