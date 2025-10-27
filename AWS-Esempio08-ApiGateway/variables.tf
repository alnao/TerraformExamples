variable "region" {
  default = "eu-central-1"
}

variable "api_name" {
  default = "esempio08-api"
}

variable "bucket_name" {
  default = "aws-esempio08-api-files"
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

variable "lambda_list_files_code" {
  default = <<-EOF
import json
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket = os.environ['BUCKET_NAME']
    
    try:
        response = s3.list_objects_v2(Bucket=bucket)
        files = []
        
        if 'Contents' in response:
            for obj in response['Contents']:
                files.append({
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'].isoformat()
                })
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'bucket': bucket,
                'count': len(files),
                'files': files
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
  EOF
}

variable "lambda_hypotenuse_code" {
  default = <<-EOF
import json
import math

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        
        cateto_a = float(body.get('cateto_a', 0))
        cateto_b = float(body.get('cateto_b', 0))
        
        if cateto_a <= 0 or cateto_b <= 0:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'I cateti devono essere positivi'})
            }
        
        ipotenusa = math.sqrt(cateto_a**2 + cateto_b**2)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'cateto_a': cateto_a,
                'cateto_b': cateto_b,
                'ipotenusa': round(ipotenusa, 2),
                'formula': 'sqrt(a² + b²)'
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
  EOF
}

variable "tags" {
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio08ApiGateway"
    CreatedBy   = "Terraform"
  }
}
