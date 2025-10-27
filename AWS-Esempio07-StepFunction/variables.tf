variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "source_bucket_name" {
  description = "Nome bucket sorgente"
  type        = string
  default     = "aws-esempio07-step-source"
}

variable "destination_bucket_name" {
  description = "Nome bucket destinazione"
  type        = string
  default     = "aws-esempio07-step-dest"
}

variable "force_destroy" {
  description = "Force destroy buckets"
  type        = bool
  default     = true
}

variable "step_function_name" {
  description = "Nome Step Function"
  type        = string
  default     = "s3-copy-and-log-workflow"
}

variable "logger_function_name" {
  description = "Nome Lambda logger"
  type        = string
  default     = "step-function-logger"
}

variable "lambda_logger_code" {
  description = "Codice Lambda logger"
  type        = string
  default     = <<-EOF
import json
from datetime import datetime

def lambda_handler(event, context):
    """Lambda che scrive log con print per Step Function"""
    
    action = event.get('action', 'unknown')
    timestamp = datetime.now().isoformat()
    
    print(f"[{timestamp}] Step Function Log Event")
    print(f"Action: {action}")
    
    if action == 'copy_completed':
        print(f"✓ File copied successfully")
        print(f"  Source: s3://{event.get('sourceBucket')}/{event.get('objectKey')}")
        print(f"  Destination: s3://{event.get('destinationBucket')}/{event.get('objectKey')}")
        print(f"  Copy Result: {json.dumps(event.get('copyResult', {}))}")
        
    elif action == 'copy_failed':
        print(f"✗ File copy failed")
        print(f"  Source: s3://{event.get('sourceBucket')}/{event.get('objectKey')}")
        print(f"  Error: {json.dumps(event.get('error', {}))}")
        
    elif action == 'lambda_failed':
        print(f"✗ Lambda invocation failed")
        print(f"  Error: {json.dumps(event.get('error', {}))}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Log written for action: {action}',
            'timestamp': timestamp
        })
    }
  EOF
}

variable "step_function_log_level" {
  description = "Log level (ALL, ERROR, FATAL, OFF)"
  type        = string
  default     = "ALL"
}

variable "enable_xray_tracing" {
  description = "Abilita X-Ray tracing"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention giorni log"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio07StepFunction"
    CreatedBy   = "Terraform"
  }
}
