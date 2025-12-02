import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']

def log_operation(operation, details, status='success'):
    """Registra operazione nella tabella logs"""
    table = dynamodb.Table(LOGS_TABLE)
    try:
        table.put_item(
            Item={
                'id': f"{operation}-{datetime.now().isoformat()}",
                'timestamp': Decimal(str(datetime.now().timestamp())),
                'operation': operation,
                'details': details,
                'status': status
            }
        )
    except Exception as e:
        print(f"Errore log: {e}")

def lambda_handler(event, context):
    """
    Genera presigned URL per upload file su S3
    
    Input:
    {
        "filename": "example.txt",
        "expires_in": 3600  # opzionale, default 3600 secondi
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        filename = body.get('filename')
        expires_in = body.get('expires_in', 3600)
        
        if not filename:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'filename is required'})
            }
        
        # Genera presigned URL
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': filename
            },
            ExpiresIn=expires_in,
            HttpMethod='PUT'
        )
        
        log_operation(
            'presigned_url',
            {'filename': filename, 'expires_in': expires_in}
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'presigned_url': presigned_url,
                'filename': filename,
                'bucket': BUCKET_NAME,
                'expires_in': expires_in
            })
        }
        
    except Exception as e:
        log_operation('presigned_url', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
