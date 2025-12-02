import json
import boto3
import os
import zipfile
import io
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
    Estrae file ZIP su S3
    
    Input (da EventBridge o API):
    {
        "bucket": "bucket-name",
        "key": "path/to/file.zip"
    }
    o da API Gateway:
    {
        "zip_key": "path/to/file.zip"
    }
    """
    try:
        # Parse input
        if 'body' in event:
            body = json.loads(event['body'])
            bucket = body.get('bucket', BUCKET_NAME)
            zip_key = body.get('zip_key')
        else:
            bucket = event.get('bucket', BUCKET_NAME)
            zip_key = event.get('key')
        
        if not zip_key:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'zip_key is required'})
            }
        
        # Scarica ZIP da S3
        zip_obj = s3_client.get_object(Bucket=bucket, Key=zip_key)
        buffer = io.BytesIO(zip_obj['Body'].read())
        
        extracted_files = []
        
        # Estrai file
        with zipfile.ZipFile(buffer) as zip_file:
            for file_name in zip_file.namelist():
                # Skip directories
                if file_name.endswith('/'):
                    continue
                
                # Estrai e carica su S3
                file_data = zip_file.read(file_name)
                output_key = f"extracted/{os.path.basename(zip_key).replace('.zip', '')}/{file_name}"
                
                s3_client.put_object(
                    Bucket=bucket,
                    Key=output_key,
                    Body=file_data
                )
                
                extracted_files.append(output_key)
        
        log_operation(
            'extract_zip',
            {
                'zip_key': zip_key,
                'extracted_files': extracted_files,
                'count': len(extracted_files)
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'ZIP extracted successfully',
                'extracted_files': extracted_files,
                'count': len(extracted_files)
            })
        }
        
    except zipfile.BadZipFile:
        log_operation('extract_zip', {'error': 'Invalid ZIP file'}, 'error')
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid ZIP file'})
        }
    except Exception as e:
        log_operation('extract_zip', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
