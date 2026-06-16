import json
import boto3
import os
from datetime import datetime

from utils import log_operation, api_response

s3_client = boto3.client('s3')

BUCKET_NAME = os.environ['BUCKET_NAME']
SCAN_TABLE = os.environ['DYNAMODB_SCAN_TABLE']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']


def lambda_handler(event, context):
    """
    Scansiona il bucket S3 e salva la lista dei file su DynamoDB.
    Invocata da EventBridge scheduler (default: giornaliera alle 02:00 UTC).
    """
    try:
        dynamodb = boto3.resource('dynamodb')
        scan_table = dynamodb.Table(SCAN_TABLE)
        scan_date = datetime.now().strftime('%Y-%m-%d')

        # Lista tutti i file nel bucket con paginazione
        paginator = s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=BUCKET_NAME)

        files_processed = 0
        total_size = 0

        # batch_writer gestisce automaticamente:
        # - batching a gruppi di 25 (limite DynamoDB)
        # - retry degli UnprocessedItems
        with scan_table.batch_writer() as batch:
            for page in pages:
                if 'Contents' not in page:
                    continue

                for obj in page['Contents']:
                    batch.put_item(Item={
                        'file_key': obj['Key'],
                        'scan_date': scan_date,
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'].isoformat(),
                        'etag': obj.get('ETag', '').strip('"')
                    })

                    files_processed += 1
                    total_size += obj['Size']

        log_operation(
            LOGS_TABLE,
            's3_scan',
            {
                'scan_date': scan_date,
                'files_processed': files_processed,
                'total_size': total_size
            }
        )

        return api_response(200, {
            'message': 'Scansione S3 completata con successo',
            'scan_date': scan_date,
            'files_processed': files_processed,
            'total_size': total_size
        }, cors=False)

    except Exception as e:
        log_operation(LOGS_TABLE, 's3_scan', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)}, cors=False)
