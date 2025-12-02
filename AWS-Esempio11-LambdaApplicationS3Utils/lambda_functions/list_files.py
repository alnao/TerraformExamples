import json
import boto3
import os
from datetime import datetime, timedelta
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

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
    Lista file nuovi (ultimi N giorni)
    
    Query parameters:
    - days: numero giorni (default: 1)
    - limit: massimo file da restituire (default: 100)
    """
    try:
        scan_table = dynamodb.Table(SCAN_TABLE)
        
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        days = int(params.get('days', 1))
        limit = int(params.get('limit', 100))
        
        # Calcola data di cutoff
        cutoff_date = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')
        
        # Query su ScanDateIndex
        response = scan_table.query(
            IndexName='ScanDateIndex',
            KeyConditionExpression='scan_date >= :cutoff_date',
            ExpressionAttributeValues={
                ':cutoff_date': cutoff_date
            },
            Limit=limit,
            ScanIndexForward=False  # Ordine decrescente
        )
        
        files = response.get('Items', [])
        
        # Converti Decimal in int/float per JSON
        for file in files:
            if 'size' in file:
                file['size'] = int(file['size'])
        
        log_operation(
            'list_files',
            {
                'days': days,
                'cutoff_date': cutoff_date,
                'count': len(files)
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'files': files,
                'count': len(files),
                'cutoff_date': cutoff_date
            })
        }
        
    except Exception as e:
        log_operation('list_files', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
