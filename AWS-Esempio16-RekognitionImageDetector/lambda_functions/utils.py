"""
Modulo condiviso dalle lambda dell'esempio 16.
Viene inserito in tutti gli archivi ZIP (vedi lambda.tf).
"""
import json
import os
from decimal import Decimal

# Rekognition DetectLabels accetta solo immagini JPEG e PNG
ALLOWED_EXTENSIONS = ('.jpg', '.jpeg', '.png')


def decimal_default(obj):
    """Serializzatore JSON per i Decimal restituiti da DynamoDB."""
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError(f"Tipo non serializzabile: {type(obj)}")


def api_response(status_code: int, body: dict) -> dict:
    """
    Risposta standard per l'integrazione proxy di API Gateway.

    Gli header CORS sono necessari anche qui: i metodi OPTIONS definiti in
    api_gateway_cors.tf coprono solo il preflight, non le risposte reali.
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body, default=decimal_default)
    }


def validate_filename(filename: str) -> str:
    """
    Valida il nome del file richiesto dal browser.

    Rifiuta path assoluti, path traversal, null byte e estensioni non
    supportate da Rekognition.

    Returns:
        Il nome file ripulito (senza eventuali directory).

    Raises:
        ValueError: se il nome non e' utilizzabile come key S3.
    """
    if not filename or not filename.strip():
        raise ValueError("Il nome del file non puo' essere vuoto")

    filename = filename.strip()

    if '\x00' in filename:
        raise ValueError("Il nome del file contiene caratteri non validi")

    # Si tiene solo l'ultima parte del path: niente cartelle scelte dal client
    filename = os.path.basename(filename.replace('\\', '/'))

    if not filename or filename in ('.', '..'):
        raise ValueError("Il nome del file non e' valido")

    if len(filename.encode('utf-8')) > 512:
        raise ValueError("Nome del file troppo lungo (max 512 byte)")

    if not filename.lower().endswith(ALLOWED_EXTENSIONS):
        raise ValueError(
            "Estensione non supportata: Rekognition accetta solo file "
            f"{', '.join(ALLOWED_EXTENSIONS)}"
        )

    return filename
