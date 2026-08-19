"""
Lambda 2 - presigned_url

Trigger: POST /upload-url

Body di richiesta:
    { "filename": "aereo.jpg", "content_type": "image/jpeg" }

Risposta:
    { "upload_url": "https://...", "key": "input/aereo.jpg", "expires_in": 3600 }

Il browser usa upload_url con una PUT diretta verso S3: il file non passa
quindi da API Gateway e non ci sono limiti di payload.
"""
import json
import os

import boto3
from botocore.config import Config

from utils import api_response, validate_filename

AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')

# signature_version v4 e' obbligatoria per i bucket delle region europee
s3_client = boto3.client(
    's3',
    region_name=AWS_REGION,
    config=Config(signature_version='s3v4', s3={'addressing_style': 'virtual'})
)

BUCKET_NAME = os.environ['BUCKET_NAME']
INPUT_PREFIX = os.environ.get('INPUT_PREFIX', 'input/')
EXPIRATION = int(os.environ.get('PRESIGNED_EXPIRATION', '3600'))


def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body') or '{}')
    except json.JSONDecodeError:
        return api_response(400, {'error': 'Body non in formato JSON'})

    filename = body.get('filename')
    content_type = body.get('content_type') or 'application/octet-stream'

    if not filename:
        return api_response(400, {'error': "Il campo 'filename' e' obbligatorio"})

    try:
        filename = validate_filename(filename)
    except ValueError as errore:
        return api_response(400, {'error': str(errore)})

    key = f"{INPUT_PREFIX}{filename}"

    try:
        upload_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': key,
                'ContentType': content_type
            },
            ExpiresIn=EXPIRATION,
            HttpMethod='PUT'
        )
    except Exception as errore:
        print(f"Errore nella generazione del presigned URL: {errore}")
        return api_response(500, {'error': str(errore)})

    print(f"Presigned URL generato per {key}")

    return api_response(200, {
        'upload_url': upload_url,
        'bucket': BUCKET_NAME,
        'key': key,
        'content_type': content_type,
        'expires_in': EXPIRATION
    })
