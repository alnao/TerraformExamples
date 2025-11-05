variable "region" {
  default = "eu-central-1"
}

variable "api_name" {
  default = "alnao-terraform-aws-esempio08-api"
}

variable "bucket_name" {
  default = "alnao-terraform-aws-esempio08-api-bucket"
}

variable "force_destroy" {
  default = true
}

variable "stage_name" {
  default = "prod"
}

variable "endpoint_type" {
  default = "REGIONAL"
}

variable "authorization_type" {
  default = "NONE"
}

variable "api_key_required" {
  default = false
}

variable "enable_cors" {
  default = true
}

variable "enable_xray_tracing" {
  default = false
}

variable "log_retention_days" {
  default = 7
}

variable "create_usage_plan" {
  default = false
}

variable "quota_limit" {
  default = 10000
}

variable "throttle_burst_limit" {
  default = 100
}

variable "throttle_rate_limit" {
  default = 50
}

variable "tags" {
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio08ApiGateway"
    CreatedBy   = "Terraform"
  }
}
