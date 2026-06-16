import json
import boto3
import os
import csv
import io

from utils import log_operation, api_response, validate_table_name, validate_column_name

s3_client = boto3.client('s3')

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']

# Credenziali RDS passate come variabili d'ambiente Lambda (criptate at-rest)
# Questo evita la necessità di un VPC Endpoint Interface per Secrets Manager
DB_HOST = os.environ.get('DB_HOST', '')
DB_USERNAME = os.environ.get('DB_USERNAME', '')
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')
DB_DATABASE = os.environ.get('DB_DATABASE', '')
DB_PORT = int(os.environ.get('DB_PORT', '3306'))


def lambda_handler(event, context):
    """
    Carica dati da un file CSV su S3 in una tabella RDS Aurora MySQL.

    NOTA: Richiede Lambda Layer con pymysql installato.
    Vedi variabile Terraform: lambda_layer_arns_rds

    Input (body JSON):
    {
        "csv_key": "path/to/file.csv",
        "table_name": "target_table"  # solo lettere, cifre, underscore
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        csv_key = body.get('csv_key')
        table_name_raw = body.get('table_name', 'imported_data')

        if not csv_key:
            return api_response(400, {'error': 'csv_key is required'})

        # Valida nome tabella per prevenire SQL injection
        try:
            table_name = validate_table_name(table_name_raw)
        except ValueError as e:
            return api_response(400, {'error': str(e)})

        if not DB_HOST:
            return api_response(500, {'error': 'Credenziali RDS non configurate (DB_HOST vuoto)'})

        # Scarica CSV da S3
        csv_obj = s3_client.get_object(Bucket=BUCKET_NAME, Key=csv_key)
        csv_content = csv_obj['Body'].read().decode('utf-8')

        try:
            import pymysql
        except ImportError:
            error_msg = 'pymysql non trovato. Aggiungere un Lambda Layer con pymysql installato.'
            log_operation(LOGS_TABLE, 'upload_to_rds', {'error': error_msg}, 'error')
            return api_response(500, {
                'error': error_msg,
                'suggestion': 'Creare un layer con: pip install pymysql -t python/ && zip -r layer.zip python/'
            })

        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USERNAME,
            password=DB_PASSWORD,
            database=DB_DATABASE,
            port=DB_PORT,
            connect_timeout=10,
            autocommit=False
        )

        try:
            cursor = connection.cursor()
            csv_reader = csv.reader(io.StringIO(csv_content))

            # Leggi header e valida ogni nome colonna
            raw_headers = next(csv_reader)
            try:
                headers = [validate_column_name(h.strip()) for h in raw_headers]
            except ValueError as e:
                return api_response(400, {'error': f'Header CSV non valido: {e}'})

            # Crea tabella se non esiste — nomi già validati, sicuri da usare direttamente
            columns_def = ', '.join([f"`{col}` VARCHAR(255)" for col in headers])
            create_table_sql = (
                f"CREATE TABLE IF NOT EXISTS `{table_name}` ("
                f"  id INT AUTO_INCREMENT PRIMARY KEY,"
                f"  {columns_def},"
                f"  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
                f")"
            )
            cursor.execute(create_table_sql)

            # Insert con parametri bind (sicuro da SQL injection sui valori)
            col_list = ', '.join([f"`{h}`" for h in headers])
            placeholders = ', '.join(['%s'] * len(headers))
            insert_sql = f"INSERT INTO `{table_name}` ({col_list}) VALUES ({placeholders})"

            rows_inserted = 0
            batch = []
            BATCH_SIZE = 100

            for row in csv_reader:
                if len(row) != len(headers):
                    continue  # Salta righe malformate
                batch.append(tuple(row))
                if len(batch) >= BATCH_SIZE:
                    cursor.executemany(insert_sql, batch)
                    rows_inserted += len(batch)
                    batch = []

            if batch:
                cursor.executemany(insert_sql, batch)
                rows_inserted += len(batch)

            connection.commit()

        except Exception:
            connection.rollback()
            raise
        finally:
            cursor.close()
            connection.close()

        log_operation(
            LOGS_TABLE,
            'upload_to_rds',
            {
                'csv_key': csv_key,
                'table_name': table_name,
                'rows_inserted': rows_inserted
            }
        )

        return api_response(200, {
            'message': 'Dati caricati su RDS con successo',
            'table_name': table_name,
            'rows_inserted': rows_inserted
        })

    except Exception as e:
        log_operation(LOGS_TABLE, 'upload_to_rds', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)})
