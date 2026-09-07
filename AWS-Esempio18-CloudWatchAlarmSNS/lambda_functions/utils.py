"""Funzioni condivise dalle Lambda dell'esempio 18."""
import decimal
import json
import os

CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("CORS_ORIGIN", "*"),
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,OPTIONS",
}


class DecimalEncoder(json.JSONEncoder):
    """DynamoDB restituisce i numeri come Decimal, json non li sa serializzare."""

    def default(self, o):
        if isinstance(o, decimal.Decimal):
            return int(o) if o % 1 == 0 else float(o)
        return super().default(o)


def api_response(status_code, body):
    """Risposta per le integrazioni AWS_PROXY, con gli header CORS gia' inclusi."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", **CORS_HEADERS},
        "body": json.dumps(body, cls=DecimalEncoder, ensure_ascii=False),
    }
