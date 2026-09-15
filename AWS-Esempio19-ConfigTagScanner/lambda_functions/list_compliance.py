"""
Lambda dietro GET /compliance.

Legge dal CONFIGURATION AGGREGATOR, cioe' la vista unica che AWS Config
costruisce mettendo insieme le valutazioni di tutte le regioni controllate.
Mette insieme due informazioni che Config tiene separate:

  1. get_aggregate_compliance_details_by_config_rule -> chi e' COMPLIANT e chi no
     (una chiamata per regione E per regola: la nativa REQUIRED_TAGS e la
     custom Guard valutano tipi diversi, i risultati si sommano)
  2. select_aggregate_resource_config                -> i tag effettivi delle risorse
     (una sola query SQL per tutte le regioni insieme)

Incrociando i due elenchi la pagina web puo' dire non solo "questa risorsa non
va bene" ma anche "le mancano i tag cost e createdBy", e in quale regione sta.
"""
import json
import logging
import os

import boto3

from utils import api_response

logger = logging.getLogger()
logger.setLevel(logging.INFO)

config = boto3.client("config")

AGGREGATOR_NAME = os.environ["AGGREGATOR_NAME"]
ACCOUNT_ID = os.environ["ACCOUNT_ID"]
REGIONS = [r for r in os.environ.get("REGIONS", "").split(",") if r]
RULE_NAMES = [r for r in os.environ["RULE_NAMES"].split(",") if r]
REQUIRED_TAGS = [t for t in os.environ.get("REQUIRED_TAGS", "").split(",") if t]
# Valori ammessi per tag, nella forma {"environment": ["dev","test","prod"]}
ALLOWED_VALUES = json.loads(os.environ.get("ALLOWED_VALUES", "{}"))

MAX_PAGINE = 50


def lambda_handler(event, context):
    try:
        valutazioni = _valutazioni()
        tipi_valutati = sorted({v["resourceType"] for v in valutazioni})
        tag_per_risorsa = _tag_per_risorsa(tipi_valutati)
    except Exception as errore:  # pragma: no cover
        logger.exception("Errore nella lettura da AWS Config")
        return api_response(500, {"errore": str(errore)})

    risorse = []
    for valutazione in valutazioni:
        chiave = (valutazione["awsRegion"], valutazione["resourceType"], valutazione["resourceId"])
        tag = tag_per_risorsa.get(chiave, {})
        risorse.append({
            **valutazione,
            "tags": tag,
            "tag_mancanti": _tag_mancanti(tag),
            "tag_con_valore_errato": _valori_errati(tag),
        })

    risorse.sort(key=lambda r: (
        r["compliance"] != "NON_COMPLIANT", r["awsRegion"], r["resourceType"], r["resourceId"]
    ))

    conformi = sum(1 for r in risorse if r["compliance"] == "COMPLIANT")

    # Riepilogo per regione, nell'ordine di REGIONS (anche quelle senza risorse)
    per_regione = {r: {"conformi": 0, "non_conformi": 0} for r in REGIONS}
    for r in risorse:
        voce = per_regione.setdefault(r["awsRegion"], {"conformi": 0, "non_conformi": 0})
        voce["conformi" if r["compliance"] == "COMPLIANT" else "non_conformi"] += 1

    return api_response(200, {
        "regole": RULE_NAMES,
        "aggregator": AGGREGATOR_NAME,
        "regioni": REGIONS,
        "tag_richiesti": REQUIRED_TAGS,
        "valori_ammessi": ALLOWED_VALUES,
        "totale": len(risorse),
        "conformi": conformi,
        "non_conformi": len(risorse) - conformi,
        "per_regione": per_regione,
        "risorse": risorse,
    })


def _valutazioni():
    """Elenco piatto delle valutazioni della regola in tutte le regioni, conformi e non."""
    risultato = []
    for regione in REGIONS:
        for regola in RULE_NAMES:
            for tipo in ("COMPLIANT", "NON_COMPLIANT"):
                risultato.extend(_valutazioni_regola(regione, regola, tipo))

    return risultato


def _valutazioni_regola(regione, regola, tipo):
    elementi = []
    token = None
    for _ in range(MAX_PAGINE):
        parametri = {
            "ConfigurationAggregatorName": AGGREGATOR_NAME,
            "ConfigRuleName": regola,
            "AccountId": ACCOUNT_ID,
            "AwsRegion": regione,
            "ComplianceType": tipo,
            "Limit": 100,
        }
        if token:
            parametri["NextToken"] = token

        risposta = config.get_aggregate_compliance_details_by_config_rule(**parametri)
        for elemento in risposta.get("AggregateEvaluationResults", []):
            qualificatore = elemento["EvaluationResultIdentifier"]["EvaluationResultQualifier"]
            elementi.append({
                "awsRegion": elemento.get("AwsRegion", regione),
                "regola": regola,
                "resourceType": qualificatore["ResourceType"],
                "resourceId": qualificatore["ResourceId"],
                "compliance": elemento["ComplianceType"],
                "valutata_il": elemento["ResultRecordedTime"].isoformat()
                if elemento.get("ResultRecordedTime") else "",
            })

        token = risposta.get("NextToken")
        if not token:
            break

    return elementi


def _tag_per_risorsa(tipi):
    """Tag delle risorse dei tipi valutati, in tutte le regioni, con una sola query SQL.

    Con record_all_resources l'inventario contiene centinaia di tipi (ENI, route
    table, ...): il WHERE evita di scaricare i tag di risorse che la regola non guarda.
    """
    if not tipi:
        return {}
    elenco = ", ".join("'%s'" % t for t in tipi)
    query = "SELECT resourceId, resourceType, awsRegion, tags WHERE resourceType IN (%s)" % elenco
    mappa = {}
    token = None

    for _ in range(MAX_PAGINE):
        parametri = {
            "Expression": query,
            "ConfigurationAggregatorName": AGGREGATOR_NAME,
            "Limit": 100,
        }
        if token:
            parametri["NextToken"] = token

        risposta = config.select_aggregate_resource_config(**parametri)
        for riga in risposta.get("Results", []):
            elemento = json.loads(riga)
            # I tag arrivano come lista di {"key": ..., "value": ...}
            tag = {t["key"]: t.get("value", "") for t in elemento.get("tags", [])}
            chiave = (elemento.get("awsRegion", ""), elemento["resourceType"], elemento["resourceId"])
            mappa[chiave] = tag

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
