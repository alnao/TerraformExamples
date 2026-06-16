import json
import boto3
import os
import zipfile
import io

from utils import log_operation, api_response, safe_zip_extract_path

s3_client = boto3.client('s3')

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']

# Dimensione massima ZIP accettata (100 MB)
MAX_ZIP_SIZE_BYTES = 100 * 1024 * 1024


def lambda_handler(event, context):
    """
    Estrae file ZIP da S3 e carica i contenuti nella stessa directory.

    Input da API Gateway (body JSON):
    {
        "zip_key": "path/to/file.zip",
        "bucket": "bucket-name"  # opzionale, default BUCKET_NAME
    }

    Input da EventBridge:
    {
        "bucket": "bucket-name",
        "key": "path/to/file.zip"
    }
    """
    zip_key = None
    try:
        # Parse input — supporta sia API Gateway che EventBridge
        if 'body' in event:
            body = json.loads(event['body'])
            bucket = body.get('bucket', BUCKET_NAME)
            zip_key = body.get('zip_key')
        else:
            bucket = event.get('bucket', BUCKET_NAME)
            zip_key = event.get('key')

        if not zip_key:
            return api_response(400, {'error': 'zip_key is required'})

        # Verifica dimensione prima di scaricare
        head = s3_client.head_object(Bucket=bucket, Key=zip_key)
        if head['ContentLength'] > MAX_ZIP_SIZE_BYTES:
            return api_response(400, {
                'error': f'File ZIP troppo grande. Massimo consentito: {MAX_ZIP_SIZE_BYTES // (1024*1024)} MB'
            })

        # Scarica ZIP da S3
        zip_obj = s3_client.get_object(Bucket=bucket, Key=zip_key)
        buffer = io.BytesIO(zip_obj['Body'].read())

        # Directory di destinazione base (usata per la protezione Zip Slip)
        base_dir = f"extracted/{os.path.basename(zip_key).replace('.zip', '')}"

        extracted_files = []
        skipped_files = []

        with zipfile.ZipFile(buffer) as zip_file:
            for file_name in zip_file.namelist():
                # Skip directory entries
                if file_name.endswith('/'):
                    continue

                # Protezione Zip Slip: valida il path prima di estrarre
                try:
                    safe_zip_extract_path(base_dir, file_name)
                except ValueError as e:
                    print(f"Zip Slip rilevato, file ignorato: {file_name} — {e}")
                    skipped_files.append(file_name)
                    continue

                # Costruisci output key sicuro
                safe_name = os.path.normpath(file_name).lstrip('/').replace('..', '').lstrip('/')
                output_key = f"{base_dir}/{safe_name}"

                file_data = zip_file.read(file_name)
                s3_client.put_object(
                    Bucket=bucket,
                    Key=output_key,
                    Body=file_data
                )
                extracted_files.append(output_key)

        log_operation(
            LOGS_TABLE,
            'extract_zip',
            {
                'zip_key': zip_key,
                'extracted_files': extracted_files,
                'count': len(extracted_files),
                'skipped': skipped_files
            }
        )

        return api_response(200, {
            'message': 'ZIP extracted successfully',
            'extracted_files': extracted_files,
            'count': len(extracted_files),
            'skipped_files': skipped_files
        })

    except zipfile.BadZipFile:
        log_operation(LOGS_TABLE, 'extract_zip', {'error': 'Invalid ZIP file', 'zip_key': zip_key or 'unknown'}, 'error')
        return api_response(400, {'error': 'Invalid ZIP file'})
    except Exception as e:
        log_operation(LOGS_TABLE, 'extract_zip', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)})
