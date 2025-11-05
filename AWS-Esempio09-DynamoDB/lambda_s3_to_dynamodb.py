import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda function triggered by S3 events via EventBridge.
    Saves file metadata to DynamoDB table.
    
    Event structure from EventBridge:
    {
        "detail": {
            "bucket": {"name": "bucket-name"},
            "object": {"key": "file-key", "size": 1234}
        }
    }
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract S3 event details
        detail = event.get('detail', {})
        bucket_name = detail.get('bucket', {}).get('name', '')
        object_key = detail.get('object', {}).get('key', '')
        object_size = detail.get('object', {}).get('size', 0)
        event_time = event.get('time', datetime.utcnow().isoformat())
        event_name = detail.get('reason', 'ObjectCreated')
        
        if not bucket_name or not object_key:
            raise ValueError("Missing bucket name or object key in event")
        
        # Prepare DynamoDB item
        # Use object_key as primary key (id)
        timestamp = int(datetime.utcnow().timestamp())
        
        item = {
            'id': object_key,  # Primary key (hash key)
            'bucket': bucket_name,
            'fileName': object_key.split('/')[-1],  # Extract filename
            'filePath': object_key,
            'fileSize': Decimal(str(object_size)),
            'eventType': event_name,
            'eventTime': event_time,
            'timestamp': Decimal(str(timestamp)),
            'processedAt': datetime.utcnow().isoformat()
        }
        
        # Save to DynamoDB
        print(f"Saving to DynamoDB table '{table_name}': {json.dumps(item, default=str)}")
        response = table.put_item(Item=item)
        
        print(f"✓ Successfully saved file metadata to DynamoDB")
        print(f"  - Bucket: {bucket_name}")
        print(f"  - File: {object_key}")
        print(f"  - Size: {object_size} bytes")
        print(f"  - Event: {event_name}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File metadata saved successfully',
                'bucket': bucket_name,
                'key': object_key,
                'table': table_name,
                'timestamp': timestamp
            })
        }
        
    except Exception as e:
        print(f"✗ Error processing S3 event: {str(e)}")
        print(f"Event details: {json.dumps(event, default=str)}")
        
        # Still return success to avoid retry loops
        # Log error for monitoring
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Failed to save file metadata'
            })
        }
