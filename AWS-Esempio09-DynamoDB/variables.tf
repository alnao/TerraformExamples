variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "alnao-terraform-aws-esempio09-dynamodb"
}

# Billing configuration
variable "billing_mode" {
  description = "Billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "billing_mode must be PROVISIONED or PAY_PER_REQUEST"
  }
}

variable "read_capacity" {
  description = "Read capacity units (for PROVISIONED mode)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units (for PROVISIONED mode)"
  type        = number
  default     = 5
}

# Key schema
variable "hash_key" {
  description = "Hash key (partition key) attribute name"
  type        = string
  default     = "id"
}

variable "hash_key_type" {
  description = "Hash key attribute type (S, N, or B)"
  type        = string
  default     = "S"
  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "hash_key_type must be S (String), N (Number), or B (Binary)"
  }
}

variable "range_key" {
  description = "Range key (sort key) attribute name (optional)"
  type        = string
  default     = ""
}

variable "range_key_type" {
  description = "Range key attribute type"
  type        = string
  default     = "S"
}

# Additional attributes for indexes
variable "additional_attributes" {
  description = "Additional attributes for GSI/LSI"
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

# Global Secondary Indexes
variable "global_secondary_indexes" {
  description = "List of global secondary indexes"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = optional(string)
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
  }))
  default = []
}

# Local Secondary Indexes
variable "local_secondary_indexes" {
  description = "List of local secondary indexes"
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = optional(string)
    non_key_attributes = optional(list(string))
  }))
  default = []
}

# Stream configuration
variable "stream_enabled" {
  description = "Enable DynamoDB Streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type (KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES)"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

# Backup and recovery
variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

# Encryption
variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (leave empty for AWS managed key)"
  type        = string
  default     = ""
}

# TTL
variable "ttl_enabled" {
  description = "Enable TTL"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "TTL attribute name"
  type        = string
  default     = "ttl"
}

# Autoscaling
variable "enable_autoscaling" {
  description = "Enable autoscaling (only for PROVISIONED mode)"
  type        = bool
  default     = false
}

variable "autoscaling_read_max_capacity" {
  description = "Maximum read capacity for autoscaling"
  type        = number
  default     = 100
}

variable "autoscaling_write_max_capacity" {
  description = "Maximum write capacity for autoscaling"
  type        = number
  default     = 100
}

variable "autoscaling_target_value" {
  description = "Target utilization percentage for autoscaling"
  type        = number
  default     = 70
}

# CloudWatch Alarms
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "List of ARNs for alarm actions (SNS topics)"
  type        = list(string)
  default     = []
}

# Global Table
variable "replica_regions" {
  description = "List of regions for global table replicas"
  type        = list(string)
  default     = []
}

# Lambda and EventBridge configuration
variable "enable_s3_lambda_integration" {
  description = "Enable S3 to Lambda via EventBridge integration"
  type        = bool
  default     = true
}

variable "enable_delete_tracking" {
  description = "Enable tracking of S3 delete events"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio09DynamoDB"
    CreatedBy   = "Terraform"
  }
}
