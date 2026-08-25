"""
Lambda 4 - textract_collect

Trigger: notifica SNS pubblicata da Amazon Textract al termine di un job
asincrono (quelli avviati da textract_analyze sui PDF).

I PDF non possono passare dalle operazioni sincrone di Textract: servono
StartDocumentAnalysis / StartDocumentTextDetection, che restituiscono subito
un JobId e avvisano su un topic SNS quando hanno finito. Il risultato va poi
recuperato con Get*, una pagina di blocchi alla volta.

Flusso:
  1. legge il messaggio SNS: JobId, Status, API e DocumentLocation
  2. dalla key del documento risale al file di opzioni sotto jobs/
  3. scarica TUTTI i blocchi con Get*, seguendo i NextToken
  4. usa lo stesso parser della via sincrona e sovrascrive output/<file>.json

Il JSON provvisorio con stato IN_ELABORAZIONE scritto da textract_analyze
viene sostituito da quello definitivo: la pagina web se ne accorge da sola.
"""
import json
import os
import time
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

from textract_parser import elabora_risposta
from utils import normalizza_opzioni

textract = boto3.client('textract')
s3_client = boto3.client('s3')

OUTPUT_PREFIX = os.environ.get('OUTPUT_PREFIX', 'output/')
RAW_PREFIX = os.environ.get('RAW_PREFIX', 'output-raw/')
JOBS_PREFIX = os.environ.get('JOBS_PREFIX', 'jobs/')
MAX_QUERIES = int(os.environ.get('MAX_QUERIES', '15'))

OPZIONI_DEFAULT = {
    'feature_types': json.loads(os.environ.get('DEFAULT_FEATURE_TYPES', '[]')),
    'queries': json.loads(os.environ.get('DEFAULT_QUERIES', '[]')),
    'min_confidence': float(os.environ.get('MIN_CONFIDENCE', '80')),
    'salva_blocchi_grezzi': os.environ.get('SALVA_BLOCCHI_GREZZI', 'false').lower() == 'true',
}

# Blocchi richiesti per ogni chiamata Get*: 1000 e' il massimo ammesso.
BLOCCHI_PER_PAGINA = 1000


def _leggi_job(bucket, key):
    """Rilegge il file di opzioni scritto dalla lambda presigned_url."""
    nome_base = key.split('/')[-1]
    job_key = f"{JOBS_PREFIX}{nome_base}.json"
    try:
        risposta = s3_client.get_object(Bucket=bucket, Key=job_key)
        return json.loads(risposta['Body'].read().decode('utf-8'))
    except (ClientError, ValueError, json.JSONDecodeError) as errore:
        print(f"{key}: file opzioni non disponibile ({errore}), si usano i default")
        return {}


def _scarica_blocchi(job_id, api):
    """
    Scarica tutti i blocchi del job seguendo la paginazione.

    Un PDF di molte pagine produce decine di migliaia di blocchi: Get*
    ne restituisce al massimo 1000 per volta e va richiamata finche' c'e'
    un NextToken.
    """
    leggi = (textract.get_document_analysis if api == 'StartDocumentAnalysis'
             else textract.get_document_text_detection)

    blocchi = []
    metadata = {}
    avvisi = []
    stato = 'SUCCEEDED'
    messaggio = None
    token = None
    pagine_scaricate = 0

    while True:
        parametri = {'JobId': job_id, 'MaxResults': BLOCCHI_PER_PAGINA}
        if token:
            parametri['NextToken'] = token

        risposta = leggi(**parametri)
        stato = risposta.get('JobStatus', stato)
        messaggio = risposta.get('StatusMessage') or messaggio
        metadata = risposta.get('DocumentMetadata') or metadata
        avvisi.extend(risposta.get('Warnings') or [])
        blocchi.extend(risposta.get('Blocks') or [])
        pagine_scaricate += 1

        token = risposta.get('NextToken')
        if not token:
            break

    print(f"job {job_id}: scaricati {len(blocchi)} blocchi in {pagine_scaricate} chiamate Get*")
    return {'Blocks': blocchi, 'DocumentMetadata': metadata,
            'JobStatus': stato, 'StatusMessage': messaggio, 'Warnings': avvisi}


def _salva_json(bucket, key_output, contenuto):
    s3_client.put_object(
        Bucket=bucket,
        Key=key_output,
        Body=json.dumps(contenuto, ensure_ascii=False, indent=2).encode('utf-8'),
        ContentType='application/json; charset=utf-8'
    )


def _elabora_notifica(notifica):
    """Gestisce un singolo messaggio pubblicato da Textract su SNS."""
    job_id = notifica.get('JobId')
    stato_job = notifica.get('Status')
    api = notifica.get('API', 'StartDocumentAnalysis')
    posizione = notifica.get('DocumentLocation') or {}
    bucket = posizione.get('S3Bucket')
    key = posizione.get('S3ObjectName')

    if not (job_id and bucket and key):
        print(f"Notifica SNS incompleta, ignorata: {notifica}")
        return None

    inizio = time.time()
    nome_base = key.split('/')[-1]
    key_output = f"{OUTPUT_PREFIX}{nome_base}.json"

    job = _leggi_job(bucket, key)
    opzioni = normalizza_opzioni(job.get('opzioni') or {}, OPZIONI_DEFAULT, MAX_QUERIES)

    risultato = {
        'file_name': job.get('file_name') or nome_base,
        'image_key': key,
        'bucket': bucket,
        'size_bytes': job.get('size_bytes', 0),
        'content_type': job.get('content_type') or 'application/pdf',
        'processed_at': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'uploaded_at': job.get('requested_at'),
        'opzioni': opzioni,
        'modalita': 'asincrona',
        'textract_api': api,
        'feature_types': opzioni['feature_types'],
        'job_id': job_id,
        'stato': 'COMPLETATO',
        'error': None,
    }

    if stato_job != 'SUCCEEDED':
        # Il job e' fallito lato Textract: si registra comunque il JSON,
        # altrimenti la pagina web resterebbe in attesa per sempre.
        risultato['stato'] = 'ERRORE'
        risultato['error'] = (
            f"{stato_job}: {notifica.get('StatusMessage') or 'job Textract non riuscito'}"
        )
        risultato['text'] = ''
        print(f"{key}: job {job_id} in stato {stato_job}")
    else:
        try:
            risposta = _scarica_blocchi(job_id, api)
            risultato.update(elabora_risposta(risposta, opzioni['min_confidence']))
            if risposta.get('Warnings'):
                risultato['warnings'] = risposta['Warnings']

            if opzioni['salva_blocchi_grezzi']:
                key_raw = f"{RAW_PREFIX}{nome_base}.raw.json"
                _salva_json(bucket, key_raw, {
                    'file_name': risultato['file_name'],
                    'image_key': key,
                    'textract_api': api,
                    'job_id': job_id,
                    'response': risposta,
                })
                risultato['raw_key'] = key_raw

            stats = risultato['stats']
            print(
                f"{key}: job {job_id} ok - {stats['n_pages']} pagine, {stats['n_lines']} righe, "
                f"{stats['n_words']} parole, {stats['n_tables']} tabelle, "
                f"{stats['n_forms']} campi, {stats['n_queries_answered']}/{stats['n_queries']} query risolte"
            )
        except ClientError as errore:
            codice = errore.response.get('Error', {}).get('Code', 'ClientError')
            messaggio = errore.response.get('Error', {}).get('Message', str(errore))
            risultato['stato'] = 'ERRORE'
            risultato['error'] = f"{codice}: {messaggio}"
            risultato['text'] = ''
            print(f"{key}: errore nel recupero del job {job_id}: {risultato['error']}")

    risultato['duration_ms'] = int((time.time() - inizio) * 1000)

    # Sovrascrive il JSON provvisorio IN_ELABORAZIONE scritto da textract_analyze.
    # La scrittura e' idempotente: una eventuale doppia consegna SNS non fa danni.
    _salva_json(bucket, key_output, risultato)
    print(f"{key}: risultato salvato in {key_output} (stato {risultato['stato']})")

    return risultato


def lambda_handler(event, context):
    elaborati = []

    for record in event.get('Records', []):
        corpo = (record.get('Sns') or {}).get('Message')
        if not corpo:
            print(f"Record senza messaggio SNS, ignorato: {record}")
            continue

        try:
            notifica = json.loads(corpo)
        except json.JSONDecodeError:
            print(f"Messaggio SNS non in formato JSON, ignorato: {corpo[:200]}")
            continue

        risultato = _elabora_notifica(notifica)
        if risultato:
            elaborati.append({
                'image_key': risultato['image_key'],
                'job_id': risultato['job_id'],
                'stato': risultato['stato'],
                'n_pagine': (risultato.get('stats') or {}).get('n_pages', 0),
            })

    return {'elaborati': len(elaborati), 'dettaglio': elaborati}
