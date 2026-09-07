"""
Lambda dietro GET /allarmi: legge lo storico salvato su DynamoDB.

Senza parametri fa una Scan (la tabella e' piccola e a vita breve); con il
parametro ?alarm_name= usa una Query sulla chiave di partizione, che e' la
strada corretta e molto piu' efficiente.
"""
import logging
import os

import boto3
from boto3.dynamodb.conditions import Key

from utils import api_response

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

LIMITE_DEFAULT = 50
LIMITE_MASSIMO = 200


def lambda_handler(event, context):
    parametri = event.get("queryStringParameters") or {}
    alarm_name = parametri.get("alarm_name")
    limite = _limite(parametri.get("limit"))

    try:
        if alarm_name:
            risposta = table.query(
                KeyConditionExpression=Key("alarm_name").eq(alarm_name),
                ScanIndexForward=False,  # dal piu' recente
                Limit=limite,
            )
        else:
            risposta = table.scan(Limit=LIMITE_MASSIMO)
    except Exception as errore:  # pragma: no cover
        logger.exception("Errore nella lettura da DynamoDB")
        return api_response(500, {"errore": str(errore)})

    items = risposta.get("Items", [])
    # Con la Scan l'ordine non e' garantito: si ordina qui prima di tagliare
    items.sort(key=lambda item: item.get("timestamp", ""), reverse=True)

    return api_response(200, {"totale": len(items), "allarmi": items[:limite]})


def _limite(valore):
    try:
        return max(1, min(int(valore), LIMITE_MASSIMO))
    except (TypeError, ValueError):
        return LIMITE_DEFAULT
