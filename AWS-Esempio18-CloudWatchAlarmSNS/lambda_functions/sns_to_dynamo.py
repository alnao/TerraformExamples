"""
Lambda iscritta al topic SNS degli allarmi.

Il messaggio che CloudWatch pubblica su SNS e' un JSON tecnico e poco leggibile:
questa funzione lo interpreta, ne ricava una riga sintetica e la salva su DynamoDB
per costruire lo storico degli allarmi consultabile dalla pagina web.
"""
import json
import logging
import os
import time
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

TTL_DAYS = int(os.environ.get("TTL_DAYS", "30"))

# Testo mostrato nella pagina web al posto dello stato tecnico
DESCRIZIONI = {
    "ALARM": "Allarme scattato: il sito sta rispondendo errori",
    "OK": "Rientro alla normalita': nessun errore nell'ultimo periodo",
    "INSUFFICIENT_DATA": "Dati insufficienti per valutare l'allarme",
}


def lambda_handler(event, context):
    salvati = []

    for record in event.get("Records", []):
        sns = record.get("Sns", {})
        messaggio = _parse_messaggio(sns.get("Message", ""))

        stato = messaggio.get("NewStateValue", "UNKNOWN")
        # Il campo StateChangeTime e' l'istante in cui l'allarme ha cambiato stato:
        # e' piu' significativo dell'istante di arrivo del messaggio SNS.
        istante = messaggio.get("StateChangeTime") or sns.get("Timestamp") or _adesso()

        item = {
            "alarm_name": messaggio.get("AlarmName", "sconosciuto"),
            "timestamp": istante,
            "stato": stato,
            "stato_precedente": messaggio.get("OldStateValue", "UNKNOWN"),
            "descrizione": DESCRIZIONI.get(stato, stato),
            "motivo": messaggio.get("NewStateReason", ""),
            "regione": messaggio.get("Region", ""),
            "metrica": _nome_metrica(messaggio),
            "soglia": str(messaggio.get("Trigger", {}).get("Threshold", "")),
            "messaggio_originale": json.dumps(messaggio, ensure_ascii=False)[:4000],
            # Con il TTL le righe vecchie spariscono da sole: nessuna pulizia manuale
            "ttl": int(time.time()) + TTL_DAYS * 24 * 3600,
        }

        table.put_item(Item=item)
        salvati.append(f"{item['alarm_name']}@{item['timestamp']}")
        logger.info("Salvato su DynamoDB: %s -> %s", item["alarm_name"], stato)

    return {"salvati": salvati}


def _parse_messaggio(raw):
    """Il corpo della notifica e' una stringa JSON; se non lo e' si tiene il testo."""
    try:
        return json.loads(raw)
    except (ValueError, TypeError):
        return {"AlarmName": "messaggio-non-json", "NewStateReason": str(raw)}


def _nome_metrica(messaggio):
    trigger = messaggio.get("Trigger", {})
    if trigger.get("MetricName"):
        return trigger["MetricName"]
    # Gli allarmi con metric_query (rapporto, anomalia) non hanno MetricName
    for metrica in trigger.get("Metrics", []):
        stat = metrica.get("MetricStat", {}).get("Metric", {})
        if stat.get("MetricName"):
            return stat["MetricName"]
    return "espressione"


def _adesso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f+0000")
