import json
import boto3
import os
from urllib.parse import unquote_plus

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function che lista gli oggetti in un bucket S3.
    Può ricevere il path come parametro nell'evento.
    """
    try:
        # Ottieni bucket name dall'ambiente
        bucket_name = os.environ.get('BUCKET_NAME')
        
        # Ottieni il path dall'evento (se presente)
        path = ''
        if 'queryStringParameters' in event and event['queryStringParameters']:
            path = event['queryStringParameters'].get('path', '')
        elif 'path' in event:
            path = event['path']
        
        # Decode del path se necessario
        if path:
            path = unquote_plus(path)
            if not path.endswith('/'):
                path += '/'
        
        print(f"Listing objects in bucket: {bucket_name}, path: {path}")
        
        # Lista oggetti nel bucket
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix=path,
            MaxKeys=100
        )
        
        # Prepara la risposta
        objects = []
        if 'Contents' in response:
            for obj in response['Contents']:
                objects.append({
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'].isoformat(),
                    'storage_class': obj.get('StorageClass', 'STANDARD')
                })
        
        result = {
            'bucket': bucket_name,
            'path': path,
            'count': len(objects),
            'objects': objects
        }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(result, indent=2)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
