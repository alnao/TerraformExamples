"""
Modulo condiviso per le Lambda functions.
Contiene utility comuni per evitare duplicazione di codice.
"""
import json
import os
import re
import uuid
import boto3
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')


def log_operation(logs_table_name: str, operation: str, details: dict, status: str = 'success') -> None:
    """
    Registra un'operazione nella tabella DynamoDB dei log.

    Args:
        logs_table_name: Nome della tabella DynamoDB
        operation: Nome dell'operazione (es. 'presigned_url')
        details: Dizionario con i dettagli dell'operazione
        status: Stato dell'operazione ('success' o 'error')
    """
    table = dynamodb.Table(logs_table_name)
    try:
        table.put_item(
            Item={
                'id': f"{operation}-{datetime.now().isoformat()}-{uuid.uuid4().hex[:8]}",
                'timestamp': Decimal(str(datetime.now().timestamp())),
                'operation': operation,
                'details': details,
                'status': status
            }
        )
    except Exception as e:
        print(f"Errore log: {e}")


def decimal_default(obj):
    """Serializzatore JSON per oggetti Decimal (DynamoDB)."""
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError(f"Tipo non serializzabile: {type(obj)}")


def api_response(status_code: int, body: dict, cors: bool = True) -> dict:
    """
    Costruisce la risposta HTTP standard per API Gateway.

    Args:
        status_code: Codice HTTP di risposta
        body: Dizionario da serializzare come JSON nel body
        cors: Se True, include gli header CORS (default: True)

    Returns:
        Dizionario compatibile con API Gateway proxy integration
    """
    headers = {'Content-Type': 'application/json'}
    if cors:
        headers.update({
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        })
    return {
        'statusCode': status_code,
        'headers': headers,
        'body': json.dumps(body, default=decimal_default)
    }


def validate_s3_key(filename: str) -> str:
    """
    Valida e sanitizza un nome file/key S3 per prevenire path traversal.

    Args:
        filename: Nome file da validare

    Returns:
        Nome file validato

    Raises:
        ValueError: Se il nome file non è valido
    """
    if not filename or not filename.strip():
        raise ValueError("Il nome file non può essere vuoto")

    filename = filename.strip()

    # Rifiuta null bytes
    if '\x00' in filename:
        raise ValueError("Il nome file contiene caratteri non validi")

    # Rifiuta path assoluti
    if filename.startswith('/'):
        raise ValueError("Il nome file non può essere un path assoluto")

    # Rifiuta path traversal
    normalized = os.path.normpath(filename)
    if normalized.startswith('..') or '/../' in filename or filename.endswith('/..'):
        raise ValueError("Path traversal non consentito nel nome file")

    # Rifiuta nomi troppo lunghi (S3 supporta max 1024 byte)
    if len(filename.encode('utf-8')) > 1024:
        raise ValueError("Nome file troppo lungo (max 1024 byte)")

    return filename


def validate_table_name(name: str) -> str:
    """
    Valida e sanitizza un nome di tabella SQL.
    Accetta solo caratteri alfanumerici e underscore.

    Args:
        name: Nome tabella da validare

    Returns:
        Nome tabella validato

    Raises:
        ValueError: Se il nome contiene caratteri non consentiti
    """
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]{0,63}$', name):
        raise ValueError(
            f"Nome tabella non valido: '{name}'. "
            "Sono consentiti solo lettere, cifre e underscore (max 64 caratteri, deve iniziare con lettera o _)."
        )
    return name


def validate_column_name(name: str) -> str:
    """
    Valida e sanitizza un nome di colonna SQL.

    Args:
        name: Nome colonna da validare

    Returns:
        Nome colonna validato

    Raises:
        ValueError: Se il nome contiene caratteri non consentiti
    """
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]{0,63}$', name):
        raise ValueError(
            f"Nome colonna non valido: '{name}'. "
            "Sono consentiti solo lettere, cifre e underscore."
        )
    return name


def safe_zip_extract_path(base_dir: str, file_name: str) -> str:
    """
    Costruisce un path sicuro per l'estrazione di file ZIP (protezione da Zip Slip).

    Args:
        base_dir: Directory di destinazione base
        file_name: Nome file dall'archivio ZIP

    Returns:
        Path assoluto sicuro

    Raises:
        ValueError: Se il path risultante è fuori dalla directory base
    """
    # Normalizza il path per rimuovere eventuali '..' o componenti assoluti
    safe_name = os.path.normpath(file_name).lstrip('/')
    # Rimuovi eventuali componenti che risalgono la directory
    safe_name = safe_name.replace('..', '').lstrip('/')
    if not safe_name:
        raise ValueError(f"Nome file non valido nell'archivio ZIP: '{file_name}'")
    full_path = os.path.join(base_dir, safe_name)
    # Verifica che il path risultante sia dentro base_dir
    if not os.path.abspath(full_path).startswith(os.path.abspath(base_dir)):
        raise ValueError(f"Zip Slip rilevato per il file: '{file_name}'")
    return full_path
