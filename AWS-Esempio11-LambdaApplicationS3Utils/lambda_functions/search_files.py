import json
import boto3
import os
from datetime import datetime
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
    Cerca file per nome
    
    Query parameters:
    - name: nome o parte del nome file (required)
    - limit: massimo file da restituire (default: 50)
    """
    try:
        scan_table = dynamodb.Table(SCAN_TABLE)
        
        # Parse query parameters
        params = event.get('queryStringParameters', {}) or {}
        search_name = params.get('name', '').lower()
        limit = int(params.get('limit', 50))
        
        if not search_name:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'name parameter is required'})
            }
        
        # Scan table con filtro (non efficiente per grandi volumi)
        # In produzione considerare ElasticSearch o DynamoDB con GSI
        response = scan_table.scan(
            Limit=limit
        )
        
        # Filtra risultati per nome
        matching_files = []
        for item in response.get('Items', []):
            if search_name in item['file_key'].lower():
                # Converti Decimal in int/float per JSON
                if 'size' in item:
                    item['size'] = int(item['size'])
                matching_files.append(item)
        
        log_operation(
            'search_files',
            {
                'search_name': search_name,
                'count': len(matching_files)
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'files': matching_files,
                'count': len(matching_files),
                'search_name': search_name
            })
        }
        
    except Exception as e:
        log_operation('search_files', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
