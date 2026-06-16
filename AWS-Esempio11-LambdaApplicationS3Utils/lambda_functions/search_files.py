import boto3
import os

from utils import log_operation, api_response

dynamodb = boto3.resource('dynamodb')

SCAN_TABLE = os.environ['DYNAMODB_SCAN_TABLE']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']

MAX_LIMIT = 500


def lambda_handler(event, context):
    """
    Cerca file per nome (o parte del nome) nella tabella di scansione.

    NOTA: Usa DynamoDB Scan con FilterExpression. Per grandi volumi di dati
    considerare l'integrazione con OpenSearch/ElasticSearch.

    Query parameters:
    - name:  stringa da cercare nel file_key (required)
    - limit: numero massimo di risultati (default: 50, max: 500)
    """
    try:
        scan_table = dynamodb.Table(SCAN_TABLE)

        params = event.get('queryStringParameters', {}) or {}
        search_name = params.get('name', '').strip().lower()
        limit = min(int(params.get('limit', 50)), MAX_LIMIT)

        if not search_name:
            return api_response(400, {'error': 'Il parametro "name" è obbligatorio'})

        # Scan con FilterExpression — corretto: il Limit viene applicato DOPO il filtro
        # raccogliendo pagine finché non raggiungiamo il numero di risultati desiderato
        matching_files = []
        last_evaluated_key = None

        while len(matching_files) < limit:
            scan_kwargs = {
                'FilterExpression': boto3.dynamodb.conditions.Attr('file_key').contains(search_name),
                'Limit': 100  # Leggi 100 item per volta per efficienza
            }
            if last_evaluated_key:
                scan_kwargs['ExclusiveStartKey'] = last_evaluated_key

            response = scan_table.scan(**scan_kwargs)
            matching_files.extend(response.get('Items', []))

            last_evaluated_key = response.get('LastEvaluatedKey')
            if not last_evaluated_key:
                break  # Nessun'altra pagina disponibile

        # Tronca al limite richiesto
        matching_files = matching_files[:limit]

        log_operation(
            LOGS_TABLE,
            'search_files',
            {
                'search_name': search_name,
                'count': len(matching_files)
            }
        )

        return api_response(200, {
            'files': matching_files,
            'count': len(matching_files),
            'search_name': search_name
        })

    except Exception as e:
        log_operation(LOGS_TABLE, 'search_files', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)})
