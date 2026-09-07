"""Funzioni condivise dalle Lambda dell'esempio 19."""
import json
import os

CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("CORS_ORIGIN", "*"),
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,OPTIONS",
}


def api_response(status_code, body):
    """Risposta per le integrazioni AWS_PROXY, con gli header CORS gia' inclusi."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", **CORS_HEADERS},
        "body": json.dumps(body, ensure_ascii=False, default=str),
    }
