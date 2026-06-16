import json
import boto3
import os

from utils import log_operation, api_response, validate_table_name

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']

# Credenziali RDS passate come variabili d'ambiente Lambda (criptate at-rest)
DB_HOST = os.environ.get('DB_HOST', '')
DB_USERNAME = os.environ.get('DB_USERNAME', '')
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')
DB_DATABASE = os.environ.get('DB_DATABASE', '')
DB_PORT = int(os.environ.get('DB_PORT', '3306'))


def lambda_handler(event, context):
    """
    Legge i dati da una tabella RDS Aurora MySQL e li restituisce in JSON.

    NOTA: Richiede Lambda Layer con pymysql. Specificare l'ARN in var.lambda_layer_arns_rds
    La Lambda deve essere in VPC per raggiungere RDS Aurora.

    Query parameters:
    - table_name: nome della tabella da leggere (required, solo alfanumerico + underscore)
    - limit:      numero massimo di righe (default: 100, max: 1000)
    - offset:     offset per paginazione (default: 0)
    - order_by:   colonna per ordinamento (opzionale, default: id)
    - order_dir:  direzione ordinamento: ASC o DESC (default: DESC)
    """
    try:
        params = event.get('queryStringParameters', {}) or {}
        table_name_raw = params.get('table_name', '')
        limit = min(int(params.get('limit', 100)), 1000)
        offset = max(int(params.get('offset', 0)), 0)
        order_by_raw = params.get('order_by', 'id')
        order_dir = params.get('order_dir', 'DESC').upper()

        if not table_name_raw:
            return api_response(400, {'error': 'Il parametro "table_name" è obbligatorio'})

        # Valida nome tabella per prevenire SQL injection
        try:
            table_name = validate_table_name(table_name_raw)
        except ValueError as e:
            return api_response(400, {'error': str(e)})

        # Valida order_by (solo alfanumerico + underscore, come i nomi colonna)
        try:
            order_by = validate_table_name(order_by_raw)
        except ValueError:
            return api_response(400, {'error': f"order_by non valido: '{order_by_raw}'"})

        # Valida order_dir
        if order_dir not in ('ASC', 'DESC'):
            return api_response(400, {'error': 'order_dir deve essere ASC o DESC'})

        if not DB_HOST:
            return api_response(500, {'error': 'Credenziali RDS non configurate (DB_HOST vuoto). Impostare create_rds = true.'})

        try:
            import pymysql
        except ImportError:
            error_msg = 'pymysql non trovato. Aggiungere un Lambda Layer con pymysql installato.'
            log_operation(LOGS_TABLE, 'read_from_rds', {'error': error_msg}, 'error')
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
            cursorclass=pymysql.cursors.DictCursor
        )

        try:
            cursor = connection.cursor()

            # Verifica che la tabella esista
            cursor.execute(
                "SELECT COUNT(*) AS cnt FROM information_schema.tables "
                "WHERE table_schema = %s AND table_name = %s",
                (DB_DATABASE, table_name)
            )
            if cursor.fetchone()['cnt'] == 0:
                return api_response(404, {
                    'error': f"Tabella '{table_name}' non trovata nel database '{DB_DATABASE}'"
                })

            # Conta righe totali
            cursor.execute(f"SELECT COUNT(*) AS total FROM `{table_name}`")
            total_rows = cursor.fetchone()['total']

            # Leggi dati con paginazione — nomi tabella e colonna già validati
            query = f"SELECT * FROM `{table_name}` ORDER BY `{order_by}` {order_dir} LIMIT %s OFFSET %s"
            cursor.execute(query, (limit, offset))
            rows = cursor.fetchall()

            # Converti valori non serializzabili in stringhe
            for row in rows:
                for key, value in row.items():
                    if not isinstance(value, (str, int, float, bool, type(None))):
                        row[key] = str(value)

        finally:
            cursor.close()
            connection.close()

        log_operation(
            LOGS_TABLE,
            'read_from_rds',
            {
                'table_name': table_name,
                'rows_returned': len(rows),
                'total_rows': total_rows,
                'limit': limit,
                'offset': offset
            }
        )

        return api_response(200, {
            'table_name': table_name,
            'data': rows,
            'count': len(rows),
            'total_rows': total_rows,
            'limit': limit,
            'offset': offset,
            'has_more': (offset + limit) < total_rows
        })

    except Exception as e:
        log_operation(LOGS_TABLE, 'read_from_rds', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)})
