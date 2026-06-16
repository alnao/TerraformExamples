import json
import boto3
import os
from botocore.config import Config

from utils import log_operation, api_response, validate_s3_key

AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')
s3_client = boto3.client(
    's3',
    region_name=AWS_REGION,
    config=Config(
        signature_version='s3v4',
        s3={'addressing_style': 'virtual'}
    )
)

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']


def lambda_handler(event, context):
    """
    Genera presigned URL per upload file su S3.

    Input (body JSON):
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
            return api_response(400, {'error': 'filename is required'})

        # Valida il nome file per prevenire path traversal e sovrascritture
        try:
            filename = validate_s3_key(filename)
        except ValueError as e:
            return api_response(400, {'error': str(e)})

        # Valida expires_in
        if not isinstance(expires_in, int) or expires_in < 1 or expires_in > 604800:
            return api_response(400, {
                'error': 'expires_in deve essere un intero tra 1 e 604800 secondi'
            })

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

        log_operation(LOGS_TABLE, 'presigned_url', {'filename': filename, 'expires_in': expires_in})

        return api_response(200, {
            'presigned_url': presigned_url,
            'filename': filename,
            'bucket': BUCKET_NAME,
            'expires_in': expires_in
        })

    except Exception as e:
        log_operation(LOGS_TABLE, 'presigned_url', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)})
