variable "region" {
  description = "Regione in cui il modulo lavora (deve coincidere con quella del provider passato)"
  type        = string
}

variable "settings" {
  description = "Impostazioni comuni a tutte le regioni, costruite una volta sola nel root module"
  type = object({
    project_name    = string
    account_id      = string
    tags            = map(string)
    config_role_arn = string

    # AWS Config
    create_recorder           = bool
    record_all_resources      = bool
    excluded_resource_types   = list(string)
    recorded_resource_types   = list(string)
    compliance_resource_types = list(string)
    delivery_bucket_name      = string
    delivery_frequency        = string

    # Regola REQUIRED_TAGS: stesso nome e stessi parametri in ogni regione,
    # cosi' l'aggregator e la Lambda la trovano con una sola chiave
    rule_name        = string
    rule_parameters  = map(string)
    rule_description = string
    rule_names       = list(string) # tutte le regole, per il pattern EventBridge

    enable_native_rule = bool # false con custom_rule_only

    # Regola custom Guard per i tipi che REQUIRED_TAGS non copre
    enable_custom_rule         = bool
    custom_rule_name           = string
    custom_rule_policy         = string
    custom_rule_resource_types = list(string)

    # Inoltro degli eventi NON_COMPLIANT verso il bus della regione centrale
    enable_notification = bool
    central_bus_arn     = string # "" nella regione centrale: gli eventi sono gia' li'
    forward_role_arn    = string

    # Bucket di prova
    create_demo_resources = bool
    force_destroy         = bool
  })
}
