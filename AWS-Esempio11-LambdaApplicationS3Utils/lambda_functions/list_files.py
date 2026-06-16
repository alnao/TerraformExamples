import boto3
import os
from datetime import datetime, timedelta

from utils import log_operation, api_response

dynamodb = boto3.resource('dynamodb')

SCAN_TABLE = os.environ['DYNAMODB_SCAN_TABLE']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']

# Numero massimo di giorni interrogabili in una singola richiesta
MAX_DAYS = 365


def lambda_handler(event, context):
    """
    Restituisce la lista dei file scansionati negli ultimi N giorni.

    Query parameters:
    - days:  numero di giorni da considerare (default: 1, max: 365)
    - limit: numero massimo di file da restituire per data (default: 100, max: 1000)
    """
    try:
        scan_table = dynamodb.Table(SCAN_TABLE)

        params = event.get('queryStringParameters', {}) or {}
        days = min(int(params.get('days', 1)), MAX_DAYS)
        limit = min(int(params.get('limit', 100)), 1000)

        # Genera la lista di date da interrogare (una query per data sul GSI)
        # Il GSI ScanDateIndex ha scan_date come hash key → si usa KeyConditionExpression con '='
        # Per coprire un range di giorni eseguiamo una query per ogni giorno
        all_files = []
        for day_offset in range(days):
            target_date = (datetime.now() - timedelta(days=day_offset)).strftime('%Y-%m-%d')

            response = scan_table.query(
                IndexName='ScanDateIndex',
                KeyConditionExpression=boto3.dynamodb.conditions.Key('scan_date').eq(target_date),
                Limit=limit,
                ScanIndexForward=False
            )
            all_files.extend(response.get('Items', []))

            # Rispetta il limit complessivo
            if len(all_files) >= limit:
                all_files = all_files[:limit]
                break

        log_operation(
            LOGS_TABLE,
            'list_files',
            {
                'days': days,
                'count': len(all_files)
            }
        )

        return api_response(200, {
            'files': all_files,
            'count': len(all_files),
            'days_queried': days
        })

    except Exception as e:
        log_operation(LOGS_TABLE, 'list_files', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)})
