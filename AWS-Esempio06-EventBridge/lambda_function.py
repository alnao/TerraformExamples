import json
import boto3
import os
from datetime import datetime

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function che processa eventi S3 da EventBridge.
    Viene invocata quando un file viene caricato in S3.
    """
    print(f"Event received: {json.dumps(event, default=str)}")
    
    try:
        # Estrai informazioni dall'evento EventBridge
        detail = event.get('detail', {})
        bucket_name = detail.get('bucket', {}).get('name')
        object_key = detail.get('object', {}).get('key')
        object_size = detail.get('object', {}).get('size', 0)
        event_time = event.get('time', datetime.now().isoformat())
        
        print(f"Processing S3 event:")
        print(f"  Bucket: {bucket_name}")
        print(f"  Key: {object_key}")
        print(f"  Size: {object_size} bytes")
        print(f"  Time: {event_time}")
        
        # Ottieni metadata dell'oggetto
        try:
            response = s3_client.head_object(
                Bucket=bucket_name,
                Key=object_key
            )
            
            metadata = {
                'ContentType': response.get('ContentType'),
                'ContentLength': response.get('ContentLength'),
                'LastModified': response.get('LastModified'),
                'ETag': response.get('ETag'),
                'Metadata': response.get('Metadata', {})
            }
            
            print(f"Object metadata: {json.dumps(metadata, default=str)}")
            
        except Exception as e:
            print(f"Error getting object metadata: {str(e)}")
            metadata = {}
        
        # Esegui processing custom qui
        # Ad esempio: 
        # - Validazione file
        # - Thumbnail generation
        # - Invio notifiche
        # - Aggiornamento database
        # - Etc.
        
        result = {
            'status': 'success',
            'bucket': bucket_name,
            'key': object_key,
            'size': object_size,
            'event_time': event_time,
            'metadata': metadata,
            'processed_at': datetime.now().isoformat()
        }
        
        print(f"Processing completed: {json.dumps(result, default=str)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(result, default=str)
        }
        
    except Exception as e:
        print(f"[ERROR] Processing failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'error': str(e)
            })
        }
