import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
ssm_client = boto3.client('ssm')

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']
SFTP_PRIVATE_KEY_PARAM = os.environ['SFTP_PRIVATE_KEY_PARAM']

def log_operation(operation, details, status='success'):
    """Registra operazione nella tabella logs"""
    table = dynamodb.Table(LOGS_TABLE)
    try:
        table.put_item(
            Item={
                'id': f"{operation}-{datetime.now().isoformat()}",
                'timestamp': Decimal(str(datetime.now().timestamp())),
                'operation': operation,
                'details': details,
                'status': status
            }
        )
    except Exception as e:
        print(f"Errore log: {e}")

def get_sftp_private_key():
    """Recupera chiave privata SFTP da SSM Parameter Store"""
    response = ssm_client.get_parameter(
        Name=SFTP_PRIVATE_KEY_PARAM,
        WithDecryption=True
    )
    return response['Parameter']['Value']

def lambda_handler(event, context):
    """
    Invia file da S3 via SFTP
    
    NOTA: Richiede layer con libreria paramiko
    La chiave privata deve essere in formato RSA e salvata in SSM Parameter Store
    
    Input:
    {
        "s3_key": "path/to/file.txt",
        "sftp_host": "sftp.example.com",
        "sftp_port": 22,
        "sftp_username": "user",
        "sftp_remote_path": "/upload/file.txt"
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        s3_key = body.get('s3_key')
        sftp_host = body.get('sftp_host')
        sftp_port = body.get('sftp_port', 22)
        sftp_username = body.get('sftp_username')
        sftp_remote_path = body.get('sftp_remote_path')
        
        if not all([s3_key, sftp_host, sftp_username, sftp_remote_path]):
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required parameters',
                    'required': ['s3_key', 'sftp_host', 'sftp_username', 'sftp_remote_path']
                })
            }
        
        # Download file from S3
        s3_obj = s3_client.get_object(Bucket=BUCKET_NAME, Key=s3_key)
        file_content = s3_obj['Body'].read()
        
        try:
            import paramiko
            import io
            
            # Get private key
            private_key_str = get_sftp_private_key()
            private_key = paramiko.RSAKey.from_private_key(io.StringIO(private_key_str))
            
            # Connect to SFTP
            transport = paramiko.Transport((sftp_host, int(sftp_port)))
            transport.connect(username=sftp_username, pkey=private_key)
            sftp = paramiko.SFTPClient.from_transport(transport)
            
            # Upload file
            sftp.putfo(io.BytesIO(file_content), sftp_remote_path)
            
            sftp.close()
            transport.close()
            
            log_operation(
                'sftp_send',
                {
                    's3_key': s3_key,
                    'sftp_host': sftp_host,
                    'sftp_remote_path': sftp_remote_path,
                    'file_size': len(file_content)
                }
            )
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'message': 'File sent via SFTP successfully',
                    's3_key': s3_key,
                    'sftp_remote_path': sftp_remote_path,
                    'file_size': len(file_content)
                })
            }
            
        except ImportError:
            error_msg = 'paramiko library not found. Please add Lambda layer with paramiko'
            log_operation('sftp_send', {'error': error_msg}, 'error')
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': error_msg,
                    'suggestion': 'Add Lambda layer with: pip install paramiko -t python/'
                })
            }
        
    except Exception as e:
        log_operation('sftp_send', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
