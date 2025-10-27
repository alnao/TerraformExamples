variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "bucket_name" {
  description = "Nome del bucket S3 per testing"
  type        = string
  default     = "aws-esempio05-lambda-test"
}

variable "force_destroy" {
  description = "Force destroy del bucket"
  type        = bool
  default     = true
}

# Lambda configuration
variable "lambda_function_name" {
  description = "Nome della Lambda function"
  type        = string
  default     = "s3-list-objects-function"
}

variable "lambda_runtime" {
  description = "Runtime della Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_handler" {
  description = "Handler della Lambda"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_timeout" {
  description = "Timeout in secondi"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size in MB"
  type        = number
  default     = 128
}

variable "lambda_code" {
  description = "Codice della Lambda function"
  type        = string
  default     = <<-EOF
import json
import boto3
import os
from urllib.parse import unquote_plus

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function che lista gli oggetti in un bucket S3.
    Può ricevere il path come parametro nell'evento.
    """
    try:
        # Ottieni bucket name dall'ambiente
        bucket_name = os.environ.get('BUCKET_NAME')
        
        # Ottieni il path dall'evento (se presente)
        path = ''
        if 'queryStringParameters' in event and event['queryStringParameters']:
            path = event['queryStringParameters'].get('path', '')
        elif 'path' in event:
            path = event['path']
        
        # Decode del path se necessario
        if path:
            path = unquote_plus(path)
            if not path.endswith('/'):
                path += '/'
        
        print(f"Listing objects in bucket: {bucket_name}, path: {path}")
        
        # Lista oggetti nel bucket
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix=path,
            MaxKeys=100
        )
        
        # Prepara la risposta
        objects = []
        if 'Contents' in response:
            for obj in response['Contents']:
                objects.append({
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'].isoformat(),
                    'storage_class': obj.get('StorageClass', 'STANDARD')
                })
        
        result = {
            'bucket': bucket_name,
            'path': path,
            'count': len(objects),
            'objects': objects
        }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(result, indent=2)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
  EOF
}

variable "lambda_environment_variables" {
  description = "Environment variables aggiuntive"
  type        = map(string)
  default     = {}
}

variable "lambda_layers" {
  description = "ARN dei Lambda layers"
  type        = list(string)
  default     = []
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions (-1 per unlimited)"
  type        = number
  default     = -1
}

# VPC Configuration
variable "vpc_subnet_ids" {
  description = "Subnet IDs per VPC"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security Group IDs per VPC"
  type        = list(string)
  default     = []
}

# Dead Letter Queue
variable "dead_letter_queue_arn" {
  description = "ARN della DLQ"
  type        = string
  default     = ""
}

# Function URL
variable "enable_function_url" {
  description = "Abilita Function URL"
  type        = bool
  default     = true
}

variable "function_url_auth_type" {
  description = "Authorization type (NONE o AWS_IAM)"
  type        = string
  default     = "NONE"
}

# CORS for Function URL
variable "cors_allow_credentials" {
  description = "CORS allow credentials"
  type        = bool
  default     = false
}

variable "cors_allow_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "CORS allowed methods"
  type        = list(string)
  default     = ["GET", "POST"]
}

variable "cors_allow_headers" {
  description = "CORS allowed headers"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "CORS exposed headers"
  type        = list(string)
  default     = []
}

variable "cors_max_age" {
  description = "CORS max age"
  type        = number
  default     = 3600
}

# Alias
variable "create_alias" {
  description = "Crea alias per la function"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Nome dell'alias"
  type        = string
  default     = "live"
}

variable "alias_function_version" {
  description = "Versione della function per l'alias"
  type        = string
  default     = "$LATEST"
}

# External invoke permission
variable "allow_external_invoke" {
  description = "Permetti invocazione esterna"
  type        = bool
  default     = false
}

variable "invoke_principal" {
  description = "Principal che può invocare la Lambda"
  type        = string
  default     = "apigateway.amazonaws.com"
}

variable "invoke_source_arn" {
  description = "Source ARN per l'invocazione"
  type        = string
  default     = ""
}

# Logging
variable "log_retention_days" {
  description = "Giorni di retention dei log"
  type        = number
  default     = 7
}

# CloudWatch Alarms
variable "enable_error_alarm" {
  description = "Abilita alarm per errori"
  type        = bool
  default     = false
}

variable "error_alarm_threshold" {
  description = "Threshold per alarm errori"
  type        = number
  default     = 5
}

variable "enable_throttle_alarm" {
  description = "Abilita alarm per throttling"
  type        = bool
  default     = false
}

variable "throttle_alarm_threshold" {
  description = "Threshold per alarm throttling"
  type        = number
  default     = 10
}

variable "alarm_actions" {
  description = "ARN per azioni alarm (SNS topics)"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio05Lambda"
    CreatedBy   = "Terraform"
  }
}
