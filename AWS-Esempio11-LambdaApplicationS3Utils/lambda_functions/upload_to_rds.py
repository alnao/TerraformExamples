import json
import boto3
import os
import csv
import io
from datetime import datetime
from decimal import Decimal

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
secrets_client = boto3.client('secretsmanager')

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']
SECRET_ARN = os.environ.get('SECRET_ARN', '')

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

def get_db_credentials():
    """Recupera credenziali RDS da Secrets Manager"""
    if not SECRET_ARN:
        raise Exception("SECRET_ARN not configured")
    
    response = secrets_client.get_secret_value(SecretId=SECRET_ARN)
    return json.loads(response['SecretString'])

def lambda_handler(event, context):
    """
    Carica dati CSV su RDS
    
    NOTA: Richiede layer con libreria pymysql o psycopg2
    
    Input:
    {
        "csv_key": "path/to/file.csv",
        "table_name": "target_table"
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        csv_key = body.get('csv_key')
        table_name = body.get('table_name', 'imported_data')
        
        if not csv_key:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'csv_key is required'})
            }
        
        # Get DB credentials
        db_creds = get_db_credentials()
        
        # Download CSV from S3
        csv_obj = s3_client.get_object(Bucket=BUCKET_NAME, Key=csv_key)
        csv_content = csv_obj['Body'].read().decode('utf-8')
        
        try:
            import pymysql
            
            # Connect to database
            connection = pymysql.connect(
                host=db_creds['host'],
                user=db_creds['username'],
                password=db_creds['password'],
                database=db_creds['database'],
                port=int(db_creds.get('port', 3306))
            )
            
            cursor = connection.cursor()
            csv_reader = csv.reader(io.StringIO(csv_content))
            
            # Read header
            headers = next(csv_reader)
            
            # Create table if not exists (simple version)
            columns_def = ', '.join([f"`{col}` VARCHAR(255)" for col in headers])
            create_table_sql = f"""
                CREATE TABLE IF NOT EXISTS `{table_name}` (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    {columns_def},
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """
            cursor.execute(create_table_sql)
            
            # Insert data
            placeholders = ', '.join(['%s'] * len(headers))
            insert_sql = f"INSERT INTO `{table_name}` ({', '.join([f'`{h}`' for h in headers])}) VALUES ({placeholders})"
            
            rows_inserted = 0
            for row in csv_reader:
                cursor.execute(insert_sql, row)
                rows_inserted += 1
            
            connection.commit()
            cursor.close()
            connection.close()
            
            log_operation(
                'upload_to_rds',
                {
                    'csv_key': csv_key,
                    'table_name': table_name,
                    'rows_inserted': rows_inserted
                }
            )
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'message': 'Data uploaded to RDS successfully',
                    'table_name': table_name,
                    'rows_inserted': rows_inserted
                })
            }
            
        except ImportError:
            error_msg = 'pymysql library not found. Please add Lambda layer with pymysql'
            log_operation('upload_to_rds', {'error': error_msg}, 'error')
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': error_msg,
                    'suggestion': 'Add Lambda layer with: pip install pymysql -t python/'
                })
            }
        
    except Exception as e:
        log_operation('upload_to_rds', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
