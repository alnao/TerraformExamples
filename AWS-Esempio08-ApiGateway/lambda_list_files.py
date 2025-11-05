import json
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function per listare i file in un bucket S3.
    Invocata da API Gateway GET /files
    """
    bucket = os.environ['BUCKET_NAME']
    
    try:
        response = s3.list_objects_v2(Bucket=bucket)
        files = []
        
        if 'Contents' in response:
            for obj in response['Contents']:
                files.append({
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'].isoformat()
                })
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'bucket': bucket,
                'count': len(files),
                'files': files
            })
        }
    except Exception as e:
        print(f"Error listing files: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e),
                'message': 'Failed to list files from S3 bucket'
            })
        }
