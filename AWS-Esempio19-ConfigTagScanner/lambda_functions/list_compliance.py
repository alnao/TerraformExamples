"""
Lambda dietro GET /compliance.

Mette insieme due informazioni che AWS Config tiene separate:

  1. get_compliance_details_by_config_rule -> chi e' COMPLIANT e chi no
  2. select_resource_config                -> i tag effettivi delle risorse

La seconda e' una query SQL sullo stato registrato da Config: con una sola
chiamata si prendono i tag di tutte le risorse, invece di interrogarle una a una.
Incrociando i due elenchi la pagina web puo' dire non solo "questa risorsa non
va bene" ma anche "le mancano i tag cost e createdBy".
"""
import json
import logging
import os

import boto3

from utils import api_response

logger = logging.getLogger()
logger.setLevel(logging.INFO)

config = boto3.client("config")

RULE_NAME = os.environ["RULE_NAME"]
REQUIRED_TAGS = [t for t in os.environ.get("REQUIRED_TAGS", "").split(",") if t]
# Valori ammessi per tag, nella forma {"environment": ["dev","test","prod"]}
ALLOWED_VALUES = json.loads(os.environ.get("ALLOWED_VALUES", "{}"))

MAX_PAGINE = 10


def lambda_handler(event, context):
    try:
        valutazioni = _valutazioni()
        tag_per_risorsa = _tag_per_risorsa()
    except Exception as errore:  # pragma: no cover
        logger.exception("Errore nella lettura da AWS Config")
        return api_response(500, {"errore": str(errore)})

    risorse = []
    for valutazione in valutazioni:
        chiave = (valutazione["resourceType"], valutazione["resourceId"])
        tag = tag_per_risorsa.get(chiave, {})
        risorse.append({
            **valutazione,
            "tags": tag,
            "tag_mancanti": _tag_mancanti(tag),
            "tag_con_valore_errato": _valori_errati(tag),
        })

    risorse.sort(key=lambda r: (r["compliance"] != "NON_COMPLIANT", r["resourceType"], r["resourceId"]))

    conformi = sum(1 for r in risorse if r["compliance"] == "COMPLIANT")

    return api_response(200, {
        "regola": RULE_NAME,
        "tag_richiesti": REQUIRED_TAGS,
        "valori_ammessi": ALLOWED_VALUES,
        "totale": len(risorse),
        "conformi": conformi,
        "non_conformi": len(risorse) - conformi,
        "risorse": risorse,
    })


def _valutazioni():
    """Elenco piatto delle valutazioni della regola, conformi e non."""
    risultato = []
    for tipo in ("COMPLIANT", "NON_COMPLIANT"):
        token = None
        for _ in range(MAX_PAGINE):
            parametri = {
                "ConfigRuleName": RULE_NAME,
                "ComplianceTypes": [tipo],
                "Limit": 100,
            }
            if token:
                parametri["NextToken"] = token

            risposta = config.get_compliance_details_by_config_rule(**parametri)
            for elemento in risposta.get("EvaluationResults", []):
                qualificatore = elemento["EvaluationResultIdentifier"]["EvaluationResultQualifier"]
                risultato.append({
                    "resourceType": qualificatore["ResourceType"],
                    "resourceId": qualificatore["ResourceId"],
                    "compliance": elemento["ComplianceType"],
                    "valutata_il": elemento.get("ResultRecordedTime", "").isoformat()
                    if elemento.get("ResultRecordedTime") else "",
                })

            token = risposta.get("NextToken")
            if not token:
                break

    return risultato


def _tag_per_risorsa():
    """Tag di tutte le risorse registrate, presi con una sola query SQL."""
    query = "SELECT resourceId, resourceType, tags"
    mappa = {}
    token = None

    for _ in range(MAX_PAGINE):
        parametri = {"Expression": query, "Limit": 100}
        if token:
            parametri["NextToken"] = token

        risposta = config.select_resource_config(**parametri)
        for riga in risposta.get("Results", []):
            elemento = json.loads(riga)
            # I tag arrivano come lista di {"key": ..., "value": ...}
            tag = {t["key"]: t.get("value", "") for t in elemento.get("tags", [])}
            mappa[(elemento["resourceType"], elemento["resourceId"])] = tag

        token = risposta.get("NextToken")
        if not token:
            break

    return mappa


def _tag_mancanti(tag):
    return [richiesto for richiesto in REQUIRED_TAGS if richiesto not in tag]


def _valori_errati(tag):
    """Tag presenti ma con un valore fuori dall'elenco degli ammessi."""
    errati = []
    for chiave, ammessi in ALLOWED_VALUES.items():
        if chiave in tag and ammessi and tag[chiave] not in ammessi:
            errati.append({"tag": chiave, "valore": tag[chiave], "ammessi": ammessi})
    return errati
