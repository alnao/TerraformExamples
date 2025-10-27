variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "source_bucket_name" {
  description = "Nome del bucket S3 sorgente"
  type        = string
  default     = "aws-esempio06-eventbridge-source"
}

variable "force_destroy" {
  description = "Force destroy del bucket"
  type        = bool
  default     = true
}

variable "enable_eventbridge_notification" {
  description = "Abilita notifiche EventBridge per S3"
  type        = bool
  default     = true
}

# Lambda Configuration
variable "lambda_function_name" {
  description = "Nome della Lambda function"
  type        = string
  default     = "s3-event-processor"
}

variable "lambda_runtime" {
  description = "Runtime della Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Timeout in secondi"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Memory size in MB"
  type        = number
  default     = 256
}

variable "lambda_code" {
  description = "Codice della Lambda function"
  type        = string
  default     = <<-EOF
import json
import boto3
import os
from datetime import datetime

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function che processa eventi S3 da EventBridge.
    Viene invocata quando un file viene caricato in S3.
    """
    print(f"Event received: {json.dumps(event, default=str)}")
    
    try:
        # Estrai informazioni dall'evento EventBridge
        detail = event.get('detail', {})
        bucket_name = detail.get('bucket', {}).get('name')
        object_key = detail.get('object', {}).get('key')
        object_size = detail.get('object', {}).get('size', 0)
        event_time = event.get('time', datetime.now().isoformat())
        
        print(f"Processing S3 event:")
        print(f"  Bucket: {bucket_name}")
        print(f"  Key: {object_key}")
        print(f"  Size: {object_size} bytes")
        print(f"  Time: {event_time}")
        
        # Ottieni metadata dell'oggetto
        try:
            response = s3_client.head_object(
                Bucket=bucket_name,
                Key=object_key
            )
            
            metadata = {
                'ContentType': response.get('ContentType'),
                'ContentLength': response.get('ContentLength'),
                'LastModified': response.get('LastModified'),
                'ETag': response.get('ETag'),
                'Metadata': response.get('Metadata', {})
            }
            
            print(f"Object metadata: {json.dumps(metadata, default=str)}")
            
        except Exception as e:
            print(f"Error getting object metadata: {str(e)}")
            metadata = {}
        
        # Esegui processing custom qui
        # Ad esempio: 
        # - Validazione file
        # - Thumbnail generation
        # - Invio notifiche
        # - Aggiornamento database
        # - Etc.
        
        result = {
            'status': 'success',
            'bucket': bucket_name,
            'key': object_key,
            'size': object_size,
            'event_time': event_time,
            'metadata': metadata,
            'processed_at': datetime.now().isoformat()
        }
        
        print(f"Processing completed: {json.dumps(result, default=str)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(result, default=str)
        }
        
    except Exception as e:
        print(f"[ERROR] Processing failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
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

# EventBridge Configuration
variable "eventbridge_rule_name" {
  description = "Nome della EventBridge rule"
  type        = string
  default     = "s3-object-created-rule"
}

variable "eventbridge_rule_state" {
  description = "Stato della rule (ENABLED o DISABLED)"
  type        = string
  default     = "ENABLED"
}

variable "event_detail_types" {
  description = "Tipi di eventi S3 da catturare"
  type        = list(string)
  default     = ["Object Created"]
}

variable "object_key_patterns" {
  description = "Pattern per filtrare object keys"
  type        = list(map(list(string)))
  default     = [{ "prefix" = [""] }]
}

# Input Transformer
variable "use_input_transformer" {
  description = "Usa input transformer per EventBridge target"
  type        = bool
  default     = false
}

variable "input_template" {
  description = "Template per input transformer"
  type        = string
  default     = "{\"bucket\":\"<bucket>\",\"key\":\"<key>\",\"size\":<size>,\"time\":\"<time>\"}"
}

# Retry Policy
variable "maximum_event_age" {
  description = "Maximum event age in seconds (60-86400)"
  type        = number
  default     = 3600
}

variable "maximum_retry_attempts" {
  description = "Maximum retry attempts (0-185)"
  type        = number
  default     = 2
}

# Additional Triggers
variable "enable_delete_trigger" {
  description = "Abilita trigger per eventi di delete"
  type        = bool
  default     = false
}

# Dead Letter Queue
variable "create_dlq" {
  description = "Crea SQS Dead Letter Queue"
  type        = bool
  default     = false
}

variable "dlq_arn" {
  description = "ARN della DLQ esistente"
  type        = string
  default     = ""
}

variable "dlq_message_retention_seconds" {
  description = "Message retention in DLQ (secondi)"
  type        = number
  default     = 1209600 # 14 giorni
}

# Logging
variable "log_retention_days" {
  description = "Giorni di retention dei log"
  type        = number
  default     = 7
}

# Monitoring
variable "enable_metric_filter" {
  description = "Abilita metric filter per errori"
  type        = bool
  default     = false
}

variable "enable_error_alarm" {
  description = "Abilita alarm per errori Lambda"
  type        = bool
  default     = false
}

variable "error_alarm_threshold" {
  description = "Threshold per alarm errori"
  type        = number
  default     = 5
}

variable "enable_failed_invocations_alarm" {
  description = "Abilita alarm per failed invocations EventBridge"
  type        = bool
  default     = false
}

variable "failed_invocations_threshold" {
  description = "Threshold per failed invocations"
  type        = number
  default     = 5
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
    Example     = "Esempio06EventBridge"
    CreatedBy   = "Terraform"
  }
}
