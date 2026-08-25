"""
Lambda 1 - presigned_url

Trigger: POST /upload-url

Body di richiesta:
    {
      "filename": "fattura.png",
      "content_type": "image/png",
      "size_bytes": 184320,
      "feature_types": ["TABLES", "FORMS"],
      "queries": [{ "text": "Qual e' il totale?", "alias": "totale" }],
      "min_confidence": 80,
      "salva_blocchi_grezzi": false,
      "nota": "fattura di prova"
    }

Risposta:
    {
      "upload_url": "https://...",
      "key": "input/20260825-143001-fattura.png",
      "opzioni": { ... },
      "expires_in": 3600
    }

Cosa fa, in ordine:
  1. valida nome file e opzioni Textract scelte dall'utente
  2. calcola la key S3 (con prefisso temporale, per non sovrascrivere nulla)
  3. salva le opzioni in un file JSON sotto jobs/, PRIMA di restituire l'URL
  4. restituisce il presigned URL PUT e la modalita' di analisi prevista
     (sincrona per le immagini, asincrona per i PDF)

Il punto 3 e' quello che rende il flusso davvero asincrono: quando l'immagine
arrivera' su S3 e fara' partire la lambda di analisi, il file con le opzioni
sara' gia' li' ad aspettarla. Non serve nessun coordinamento fra le due.

Perche' un file e non i metadata dell'oggetto S3? I metadata utente sono
limitati a 2 KB e devono essere US-ASCII: un elenco di query in italiano li
farebbe saltare. In piu' con il presigned URL il browser dovrebbe rispedire
esattamente gli stessi header x-amz-meta-*, pena SignatureDoesNotMatch.
"""
import json
import os
from datetime import datetime, timezone

import boto3
from botocore.config import Config

from utils import (api_response, e_pdf, estensione_minuscola,
                   normalizza_opzioni, validate_filename)

AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')

# signature_version v4 e' obbligatoria per i bucket delle region europee
s3_client = boto3.client(
    's3',
    region_name=AWS_REGION,
    config=Config(signature_version='s3v4', s3={'addressing_style': 'virtual'})
)

BUCKET_NAME = os.environ['BUCKET_NAME']
INPUT_PREFIX = os.environ.get('INPUT_PREFIX', 'input/')
JOBS_PREFIX = os.environ.get('JOBS_PREFIX', 'jobs/')
EXPIRATION = int(os.environ.get('PRESIGNED_EXPIRATION', '3600'))
MAX_QUERIES = int(os.environ.get('MAX_QUERIES', '15'))
AGGIUNGI_TIMESTAMP = os.environ.get('AGGIUNGI_TIMESTAMP', 'true').lower() == 'true'
MAX_UPLOAD_MB = float(os.environ.get('MAX_UPLOAD_MB', '10'))
MAX_PDF_MB = float(os.environ.get('MAX_PDF_MB', '100'))

OPZIONI_DEFAULT = {
    'feature_types': json.loads(os.environ.get('DEFAULT_FEATURE_TYPES', '[]')),
    'queries': json.loads(os.environ.get('DEFAULT_QUERIES', '[]')),
    'min_confidence': float(os.environ.get('MIN_CONFIDENCE', '80')),
    'salva_blocchi_grezzi': os.environ.get('SALVA_BLOCCHI_GREZZI', 'false').lower() == 'true',
}


def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body') or '{}')
    except json.JSONDecodeError:
        return api_response(400, {'error': 'Body non in formato JSON'})

    filename = body.get('filename')
    content_type = body.get('content_type') or 'application/octet-stream'

    if not filename:
        return api_response(400, {'error': "Il campo 'filename' e' obbligatorio"})

    try:
        filename = validate_filename(filename)
        opzioni = normalizza_opzioni(body, OPZIONI_DEFAULT, MAX_QUERIES)
    except ValueError as errore:
        return api_response(400, {'error': str(errore)})

    pdf = e_pdf(filename)

    # Controllo della dimensione dichiarata dal browser: i PDF passano dalle
    # operazioni asincrone e possono essere molto piu' grandi delle immagini.
    dimensione = body.get('size_bytes')
    if dimensione is not None:
        try:
            dimensione_mb = float(dimensione) / 1024 / 1024
        except (TypeError, ValueError):
            return api_response(400, {'error': "Il campo 'size_bytes' deve essere un numero"})
        limite = MAX_PDF_MB if pdf else MAX_UPLOAD_MB
        if dimensione_mb > limite:
            return api_response(400, {
                'error': f"Il file pesa {dimensione_mb:.1f} MB: il limite per "
                         f"{'i PDF' if pdf else 'le immagini'} e' {limite:.0f} MB"
            })

    # Le notifiche S3 filtrano il suffisso in modo case-sensitive: senza questa
    # normalizzazione un file caricato come "Scansione.PDF" non farebbe partire
    # nessuna analisi. Il nome originale resta comunque nel file di opzioni.
    nome_key = estensione_minuscola(filename)

    # Prefisso temporale: due upload dello stesso file non si sovrascrivono
    # e la lista ordinata per key risulta gia' cronologica.
    adesso = datetime.now(timezone.utc)
    if AGGIUNGI_TIMESTAMP:
        key = f"{INPUT_PREFIX}{adesso.strftime('%Y%m%d-%H%M%S')}-{nome_key}"
    else:
        key = f"{INPUT_PREFIX}{nome_key}"

    nome_base = key.split('/')[-1]
    job_key = f"{JOBS_PREFIX}{nome_base}.json"

    job = {
        'file_name': filename,
        'image_key': key,
        'requested_at': adesso.isoformat(timespec='seconds'),
        'content_type': content_type,
        'size_bytes': dimensione or 0,
        'modalita': 'asincrona' if pdf else 'sincrona',
        'opzioni': opzioni,
    }

    try:
        # Le opzioni vanno scritte prima di consegnare l'URL al browser
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=job_key,
            Body=json.dumps(job, ensure_ascii=False, indent=2).encode('utf-8'),
            ContentType='application/json'
        )

        upload_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': key,
                'ContentType': content_type
            },
            ExpiresIn=EXPIRATION,
            HttpMethod='PUT'
        )
    except Exception as errore:
        print(f"Errore nella preparazione dell'upload di {key}: {errore}")
        return api_response(500, {'error': str(errore)})

    # I PDF non possono passare dalle operazioni sincrone (accettano una sola
    # pagina): per loro si usano le Start*, con il risultato raccolto via SNS.
    if pdf:
        api_textract = ('StartDocumentAnalysis' if opzioni['feature_types']
                        else 'StartDocumentTextDetection')
    else:
        api_textract = 'AnalyzeDocument' if opzioni['feature_types'] else 'DetectDocumentText'

    print(f"Presigned URL generato per {key} - API {api_textract} - feature {opzioni['feature_types']}")

    return api_response(200, {
        'upload_url': upload_url,
        'bucket': BUCKET_NAME,
        'key': key,
        'file_name': filename,
        'job_key': job_key,
        'content_type': content_type,
        'expires_in': EXPIRATION,
        'textract_api': api_textract,
        'modalita': 'asincrona' if pdf else 'sincrona',
        'opzioni': opzioni,
    })
