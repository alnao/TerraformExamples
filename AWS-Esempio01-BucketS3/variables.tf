
variable "region" {
  description = "AWS region where to create resources"
  type        = string
  default     = "eu-central-1" # Francoforte
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "alnao-dev-terraform-esempio01-buckets3"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Name        = "aws-esempio01.bucket"
    Environment = "dev"
    Project     = "Development.aws.terraform01-BucketS3"
    Owner       = "AlNao"
    CostCenter  = "dev"
    ManagedBy   = "Terraform"
  }
}
variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Force destroy bucket even if not empty"
  type        = bool
  default     = false
}

variable "acl" {
  description = "Canned ACL to apply"
  type        = string
  default     = "private"
}
