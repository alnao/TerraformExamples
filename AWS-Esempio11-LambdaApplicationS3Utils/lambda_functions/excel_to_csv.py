import json
import boto3
import os
import csv
import io
from datetime import datetime
from decimal import Decimal

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']

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

def lambda_handler(event, context):
    """
    Converte file Excel (.xlsx) in CSV
    
    NOTA: Richiede layer con libreria openpyxl o pandas
    Questa è una versione semplificata che presuppone layer installato
    
    Input:
    {
        "excel_key": "path/to/file.xlsx",
        "sheet_name": "Sheet1"  # opzionale
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        excel_key = body.get('excel_key')
        sheet_name = body.get('sheet_name', 0)  # Default first sheet
        
        if not excel_key:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'excel_key is required'})
            }
        
        # Scarica Excel da S3
        excel_obj = s3_client.get_object(Bucket=BUCKET_NAME, Key=excel_key)
        excel_data = excel_obj['Body'].read()
        
        try:
            import openpyxl
            workbook = openpyxl.load_workbook(io.BytesIO(excel_data))
            
            # Seleziona sheet
            if isinstance(sheet_name, str):
                sheet = workbook[sheet_name]
            else:
                sheet = workbook.worksheets[sheet_name]
            
            # Converti in CSV
            csv_buffer = io.StringIO()
            writer = csv.writer(csv_buffer)
            
            for row in sheet.iter_rows(values_only=True):
                writer.writerow(row)
            
            # Upload CSV su S3
            csv_key = excel_key.replace('.xlsx', '.csv').replace('.xls', '.csv')
            s3_client.put_object(
                Bucket=BUCKET_NAME,
                Key=csv_key,
                Body=csv_buffer.getvalue(),
                ContentType='text/csv'
            )
            
            log_operation(
                'excel_to_csv',
                {
                    'excel_key': excel_key,
                    'csv_key': csv_key,
                    'sheet_name': str(sheet_name)
                }
            )
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'message': 'Excel converted to CSV successfully',
                    'csv_key': csv_key
                })
            }
            
        except ImportError:
            # Fallback se openpyxl non è disponibile
            error_msg = 'openpyxl library not found. Please add Lambda layer with openpyxl'
            log_operation('excel_to_csv', {'error': error_msg}, 'error')
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': error_msg,
                    'suggestion': 'Add Lambda layer with: pip install openpyxl -t python/'
                })
            }
        
    except Exception as e:
        log_operation('excel_to_csv', {'error': str(e)}, 'error')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
