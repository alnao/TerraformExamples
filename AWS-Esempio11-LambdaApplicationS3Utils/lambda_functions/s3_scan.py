import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['BUCKET_NAME']
SCAN_TABLE = os.environ['DYNAMODB_SCAN_TABLE']
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
    Scansiona bucket S3 e salva lista file su DynamoDB
    Invocata da EventBridge scheduler (giornaliera)
    """
    try:
        scan_table = dynamodb.Table(SCAN_TABLE)
        scan_date = datetime.now().strftime('%Y-%m-%d')
        
        # Lista tutti i file nel bucket
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=BUCKET_NAME)
        
        files_processed = 0
        total_size = 0
        
        for page in pages:
            if 'Contents' not in page:
                continue
            
            for obj in page['Contents']:
                file_key = obj['Key']
                file_size = obj['Size']
                last_modified = obj['LastModified'].isoformat()
                
                # Salva in DynamoDB
                scan_table.put_item(
                    Item={
                        'file_key': file_key,
                        'scan_date': scan_date,
                        'size': file_size,
                        'last_modified': last_modified,
                        'etag': obj.get('ETag', '').strip('"')
                    }
                )
                
                files_processed += 1
                total_size += file_size
        
        log_operation(
            's3_scan',
            {
                'scan_date': scan_date,
                'files_processed': files_processed,
                'total_size': total_size
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'S3 scan completed successfully',
                'scan_date': scan_date,
                'files_processed': files_processed,
                'total_size': total_size
            })
        }
        
    except Exception as e:
        log_operation('s3_scan', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
