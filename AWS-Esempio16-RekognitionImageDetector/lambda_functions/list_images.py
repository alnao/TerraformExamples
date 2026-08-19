"""
Lambda 3 - list_images

Trigger: GET /images?rilevanti=true&limit=50

Con rilevanti=true si usa una Query sul GSI RilevanteIndex (immagine_rilevante = SI),
altrimenti una Scan della tabella.

Per ogni riga viene aggiunto preview_url, un presigned URL GET di breve durata
che permette alla pagina web di mostrare l'anteprima senza rendere pubblico il bucket.
"""
import os

import boto3
from boto3.dynamodb.conditions import Key
from botocore.config import Config

from utils import api_response

AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client(
    's3',
    region_name=AWS_REGION,
    config=Config(signature_version='s3v4', s3={'addressing_style': 'virtual'})
)

TABLE_NAME = os.environ['TABLE_NAME']
BUCKET_NAME = os.environ['BUCKET_NAME']
KEYWORD = os.environ.get('KEYWORD', 'airplane')
PREVIEW_EXPIRE = int(os.environ.get('PREVIEW_EXPIRE', '300'))

table = dynamodb.Table(TABLE_NAME)

LIMIT_DEFAULT = 50
LIMIT_MAX = 200


def _preview_url(key):
    """Presigned URL GET per l'anteprima dell'immagine."""
    try:
        return s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': BUCKET_NAME, 'Key': key},
            ExpiresIn=PREVIEW_EXPIRE
        )
    except Exception as errore:
        print(f"Anteprima non disponibile per {key}: {errore}")
        return None


def lambda_handler(event, context):
    parametri = event.get('queryStringParameters') or {}
    solo_rilevanti = str(parametri.get('rilevanti', 'false')).lower() in ('true', '1', 'si', 'yes')

    try:
        limit = int(parametri.get('limit', LIMIT_DEFAULT))
    except (TypeError, ValueError):
        limit = LIMIT_DEFAULT
    limit = max(1, min(limit, LIMIT_MAX))

    try:
        if solo_rilevanti:
            risultato = table.query(
                IndexName='RilevanteIndex',
                KeyConditionExpression=Key('immagine_rilevante').eq('SI'),
                ScanIndexForward=False,  # dalle piu' recenti
                Limit=limit
            )
        else:
            risultato = table.scan(Limit=limit)
    except Exception as errore:
        print(f"Errore nella lettura della tabella: {errore}")
        return api_response(500, {'error': str(errore)})

    items = risultato.get('Items', [])

    # La Scan non e' ordinata: si ordina lato lambda per data discendente
    items.sort(key=lambda i: i.get('upload_timestamp', ''), reverse=True)

    for item in items:
        item['preview_url'] = _preview_url(item['image_key'])

    return api_response(200, {
        'keyword': KEYWORD,
        'solo_rilevanti': solo_rilevanti,
        'count': len(items),
        'items': items
    })
