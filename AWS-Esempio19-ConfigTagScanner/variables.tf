# ====================================
# REGIONI
#
# AWS Config e' un servizio REGIONALE: recorder e regola vanno creati in ogni
# regione da controllare. Le quattro regioni qui sotto hanno ciascuna un
# provider con alias in main.tf e un blocco module in config.tf: per
# aggiungerne una quinta vanno aggiunti entrambi (Terraform non permette di
# creare provider in un ciclo).
# ====================================

variable "regions" {
  description = "Regioni in cui attivare recorder e regola. Ammesse: us-west-2 (Oregon), eu-west-1 (Irlanda), eu-central-1 (Francoforte), us-east-2 (Ohio), us-east-1 (N. Virginia)"
  type        = list(string)
  default     = ["us-west-2", "eu-west-1", "eu-central-1", "us-east-2", "us-east-1"]

  validation {
    condition = length(var.regions) > 0 && alltrue([
      for r in var.regions : contains(["us-west-2", "eu-west-1", "eu-central-1", "us-east-2", "us-east-1"], r)
    ])
    error_message = "regions accetta solo us-west-2, eu-west-1, eu-central-1, us-east-2, us-east-1 (almeno una). Per altre regioni aggiungere provider alias e blocco module."
  }
}

variable "home_region" {
  description = "Regione centrale: qui stanno bucket di consegna, aggregator, SNS, Lambda, API e sito. Deve essere una delle regioni ammesse"
  type        = string
  default     = "us-west-2"

  validation {
    condition     = contains(["us-west-2", "eu-west-1", "eu-central-1", "us-east-2", "us-east-1"], var.home_region)
    error_message = "home_region deve essere una fra us-west-2, eu-west-1, eu-central-1, us-east-2, us-east-1."
  }
}

variable "project_name" {
  description = "Prefisso usato per tutte le risorse create. Solo minuscole, numeri e trattini: finisce nei nomi dei bucket S3"
  type        = string
  default     = "alnao-terraform-esempio19"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}$", var.project_name))
    error_message = "project_name deve contenere solo minuscole, numeri e trattini (e' usato nei nomi dei bucket S3), massimo 41 caratteri."
  }
}

# ====================================
# I TAG OBBLIGATORI
# ====================================

variable "required_tag_keys" {
  description = "Tag che ogni risorsa deve avere. La regola nativa REQUIRED_TAGS ne accetta al massimo sei"
  type        = list(string)
  default     = ["project", "cost", "environment", "createdWith", "createdBy"]

  validation {
    condition     = length(var.required_tag_keys) > 0 && length(var.required_tag_keys) <= 6
    error_message = "La regola REQUIRED_TAGS di AWS Config accetta da uno a sei tag."
  }
}

variable "allowed_tag_values" {
  description = "Valori ammessi per alcuni tag; i tag non elencati accettano qualsiasi valore"
  type        = map(list(string))
  default = {
    environment = ["dev", "test", "prod"]
    createdWith = ["terraform", "console", "cli"]
  }
}

# ====================================
# AWS CONFIG
# ====================================

variable "regions_with_existing_recorder" {
  description = "Regioni in cui il configuration recorder esiste gia' (Control Tower, Security Hub...). AWS ne ammette UNO SOLO per regione: qui il modulo crea solo la regola"
  type        = list(string)
  default     = []
}

variable "record_all_resources" {
  description = "Se true il recorder registra TUTTI i tipi di risorsa supportati da Config (centinaia) tranne excluded_resource_types; se false solo quelli in recorded_resource_types"
  type        = bool
  default     = false
}

variable "excluded_resource_types" {
  description = "Tipi NON registrati quando record_all_resources = true. AWS::Config::ResourceCompliance e' l'esito delle valutazioni: registrarlo costa un CI per ogni cambio di stato e non serve a nulla per i tag. I tipi IAM sono globali: con la strategia a esclusione verrebbero registrati (e pagati) in ogni regione"
  type        = list(string)
  default = [
    "AWS::Config::ResourceCompliance",
    "AWS::IAM::Group",
    "AWS::IAM::Policy",
    "AWS::IAM::Role",
    "AWS::IAM::User",
  ]
}

# I 30 tipi di risorsa che la regola nativa REQUIRED_TAGS sa valutare
# (https://docs.aws.amazon.com/config/latest/developerguide/required-tags.html).
# Lambda, SNS, SQS, API Gateway, IAM, EKS, ECS... NON ci sono: per quelli
# serve una custom rule.
locals {
  required_tags_supported_types = [
    "AWS::ACM::Certificate",
    "AWS::AutoScaling::AutoScalingGroup",
    "AWS::CloudFormation::Stack",
    "AWS::CodeBuild::Project",
    "AWS::DynamoDB::Table",
    "AWS::EC2::CustomerGateway",
    "AWS::EC2::Instance",
    "AWS::EC2::InternetGateway",
    "AWS::EC2::NetworkAcl",
    "AWS::EC2::NetworkInterface",
    "AWS::EC2::RouteTable",
    "AWS::EC2::SecurityGroup",
    "AWS::EC2::Subnet",
    "AWS::EC2::Volume",
    "AWS::EC2::VPC",
    "AWS::EC2::VPNConnection",
    "AWS::EC2::VPNGateway",
    "AWS::ElasticLoadBalancing::LoadBalancer",
    "AWS::ElasticLoadBalancingV2::LoadBalancer",
    "AWS::RDS::DBInstance",
    "AWS::RDS::DBSecurityGroup",
    "AWS::RDS::DBSnapshot",
    "AWS::RDS::DBSubnetGroup",
    "AWS::RDS::EventSubscription",
    "AWS::Redshift::Cluster",
    "AWS::Redshift::ClusterParameterGroup",
    "AWS::Redshift::ClusterSecurityGroup",
    "AWS::Redshift::ClusterSnapshot",
    "AWS::Redshift::ClusterSubnetGroup",
    "AWS::S3::Bucket",
  ]
}

variable "recorded_resource_types" {
  description = "Tipi di risorsa registrati quando record_all_resources = false; lista vuota = i 30 tipi di REQUIRED_TAGS piu' quelli della regola custom, cioe' solo cio' che le regole valutano. Ridurre l'elenco riduce il costo di Config"
  type        = list(string)
  default     = []
}

# ====================================
# LA REGOLA CUSTOM (Guard) PER I TIPI CHE REQUIRED_TAGS NON COPRE
# ====================================

variable "enable_custom_rule" {
  description = "Crea anche una regola custom (CloudFormation Guard) che verifica gli stessi tag sui tipi di risorsa che REQUIRED_TAGS non sa valutare"
  type        = bool
  default     = true
}

variable "tag_keys_case_insensitive" {
  description = "La regola custom Guard accetta le chiavi anche con iniziale maiuscola o tutte maiuscole (project, Project, PROJECT). La regola nativa REQUIRED_TAGS NON lo permette: per averlo ovunque usare custom_rule_only"
  type        = bool
  default     = true
}

variable "custom_rule_only" {
  description = "Usa SOLO la regola custom Guard, anche per i 30 tipi di REQUIRED_TAGS (che non viene creata). Serve quando si vuole tag_keys_case_insensitive su tutte le risorse"
  type        = bool
  default     = false
}

variable "custom_rule_resource_types" {
  description = "Tipi di risorsa valutati dalla regola custom: taggabili, registrati da Config e NON coperti da REQUIRED_TAGS. Massimo 100"
  type        = list(string)
  default = [
    "AWS::Lambda::Function",
    "AWS::SNS::Topic",
    "AWS::SQS::Queue",
    "AWS::ApiGateway::RestApi",
    "AWS::ApiGateway::Stage",
    "AWS::ApiGatewayV2::Api",
    "AWS::ApiGatewayV2::Stage",
    "AWS::StepFunctions::StateMachine",
    "AWS::Events::Rule",
    "AWS::Logs::LogGroup",
    "AWS::CloudWatch::Alarm",
    "AWS::KMS::Key",
    "AWS::SecretsManager::Secret",
    "AWS::ECS::Cluster",
    "AWS::ECS::Service",
    "AWS::ECS::TaskDefinition",
    "AWS::EKS::Cluster",
    "AWS::ECR::Repository",
    "AWS::EFS::FileSystem",
    "AWS::RDS::DBCluster",
    "AWS::RDS::DBClusterSnapshot",
    "AWS::OpenSearch::Domain",
    "AWS::Elasticsearch::Domain",
    "AWS::Kinesis::Stream",
    "AWS::KinesisFirehose::DeliveryStream",
    "AWS::MSK::Cluster",
    "AWS::Glue::Job",
    "AWS::Athena::WorkGroup",
    "AWS::SageMaker::NotebookInstance",
    "AWS::CloudTrail::Trail",
    "AWS::CodePipeline::Pipeline",
    "AWS::CodeDeploy::Application",
    "AWS::EC2::EIP",
    "AWS::EC2::NatGateway",
    "AWS::EC2::LaunchTemplate",
    "AWS::EC2::TransitGateway",
    "AWS::EC2::VPCEndpoint",
    "AWS::EC2::VPCPeeringConnection",
    "AWS::ElasticBeanstalk::Application",
    "AWS::ElasticBeanstalk::Environment",
    "AWS::Backup::BackupVault",
    "AWS::Backup::BackupPlan",
    "AWS::WAFv2::WebACL",
    "AWS::Cognito::UserPool",
    "AWS::AppSync::GraphQLApi",
    "AWS::Batch::ComputeEnvironment",
    "AWS::Batch::JobQueue",
    "AWS::DMS::ReplicationInstance",
    "AWS::NetworkFirewall::Firewall",
    "AWS::GuardDuty::Detector",
    "AWS::S3::AccessPoint",
  ]

  validation {
    # Con custom_rule_only si aggiungono i 30 tipi di REQUIRED_TAGS
    condition     = length(var.custom_rule_resource_types) <= 70
    error_message = "Lo scope di una config rule accetta al massimo 100 tipi di risorsa: qui al massimo 70, perche' con custom_rule_only si aggiungono i 30 di REQUIRED_TAGS."
  }
}

variable "compliance_resource_types" {
  description = "Tipi di risorsa valutati dalla regola; lista vuota = nessuno scope, cioe' tutti i 30 tipi supportati da REQUIRED_TAGS fra quelli registrati"
  type        = list(string)
  default     = []
}

variable "delivery_frequency" {
  description = "Frequenza degli snapshot di configurazione consegnati su S3"
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition = contains([
      "One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"
    ], var.delivery_frequency)
    error_message = "Frequenza non valida per il delivery channel di AWS Config."
  }
}

variable "bucket_name" {
  description = "Bucket unico, nella regione centrale, dove Config di tutte le regioni consegna snapshot e cronologia (vuoto = <project_name>-config-<account_id>)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Giorni dopo i quali gli oggetti scritti da Config nel bucket vengono cancellati"
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Permette il destroy del bucket anche se contiene oggetti"
  type        = bool
  default     = true
}

# ====================================
# NOTIFICHE
# ====================================

variable "sns_topic_name" {
  description = "Nome del topic SNS (vuoto = <project_name>-non-compliant)"
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "Email iscritta al topic SNS (vuoto = nessuna iscrizione)"
  type        = string
  default     = ""
}

variable "enable_eventbridge_notification" {
  description = "Notifica su SNS ogni volta che una risorsa diventa NON_COMPLIANT"
  type        = bool
  default     = true
}

# ====================================
# RISORSE DI PROVA
# ====================================

variable "create_demo_resources" {
  description = "Crea in ogni regione due bucket S3, uno con tutti i tag e uno senza, per vedere subito la regola al lavoro"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tag applicati alle risorse dell'esempio"
  type        = map(string)
  default = {
    project     = "alnao-terraform-esempio19"
    cost        = "tagScanner"
    environment = "prod"
    createdWith = "terraform"
    createdBy   = "alnao"
  }
}

# ====================================
# CRUSCOTTO WEB: LAMBDA, API, SITO S3
# ====================================

variable "website_bucket_name" {
  description = "Bucket del sito statico (vuoto = <project_name>-web-<account_id>)"
  type        = string
  default     = ""
}

variable "api_name" {
  description = "Nome della REST API (vuoto = <project_name>-api)"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "Nome dello stage dell'API Gateway"
  type        = string
  default     = "dev"
}

variable "cors_allowed_origin" {
  description = "Origine autorizzata a chiamare l'API dal browser"
  type        = string
  default     = "*"
}
