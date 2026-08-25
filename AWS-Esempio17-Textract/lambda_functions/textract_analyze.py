"""
Lambda 2 - textract_analyze

Trigger: evento S3 ObjectCreated sulla cartella input/ del bucket.
L'invocazione e' asincrona: il browser non aspetta il risultato, riceve solo
la conferma dell'upload e poi va a leggere il JSON quando c'e'.

Flusso:
  1. legge la key del file appena caricato
  2. rilegge da jobs/ le opzioni Textract scelte al momento dell'upload
     (feature TABLES / FORMS / QUERIES / SIGNATURES / LAYOUT, query, soglia)
  3. sceglie la via giusta in base al tipo di file:

     IMMAGINE (.jpg .jpeg .png) - via SINCRONA
       DetectDocumentText se non e' richiesta nessuna feature, altrimenti
       AnalyzeDocument. La risposta arriva subito e il JSON e' gia' definitivo.

     PDF - via ASINCRONA
       StartDocumentTextDetection / StartDocumentAnalysis restituiscono solo
       un JobId; Textract avvisa su SNS quando ha finito e i blocchi vengono
       raccolti dalla lambda textract_collect. Qui si scrive un JSON
       provvisorio con stato IN_ELABORAZIONE, che verra' sovrascritto.

     Le operazioni sincrone accettano una sola pagina, quindi un PDF (che puo'
     averne molte) non puo' passare di li'.

  4. trasforma i blocchi in una struttura leggibile (textract_parser.py)
  5. salva output/<nome file>.json con nome file e testo estratto

Anche gli errori producono un JSON, con stato ERRORE: cosi' la pagina web
non lascia mai una riga in "in corso" per sempre.
"""
import hashlib
import json
import os
import re
import time
import urllib.parse
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

from textract_parser import elabora_risposta
from utils import ALLOWED_EXTENSIONS, e_pdf, normalizza_opzioni

textract = boto3.client('textract')
s3_client = boto3.client('s3')

INPUT_PREFIX = os.environ.get('INPUT_PREFIX', 'input/')
OUTPUT_PREFIX = os.environ.get('OUTPUT_PREFIX', 'output/')
RAW_PREFIX = os.environ.get('RAW_PREFIX', 'output-raw/')
JOBS_PREFIX = os.environ.get('JOBS_PREFIX', 'jobs/')
MAX_QUERIES = int(os.environ.get('MAX_QUERIES', '15'))

# Canale di notifica usato dai job asincroni sui PDF: Textract assume il ruolo
# TEXTRACT_ROLE_ARN e pubblica su SNS_TOPIC_ARN quando il job e' finito.
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
TEXTRACT_ROLE_ARN = os.environ.get('TEXTRACT_ROLE_ARN', '')

OPZIONI_DEFAULT = {
    'feature_types': json.loads(os.environ.get('DEFAULT_FEATURE_TYPES', '[]')),
    'queries': json.loads(os.environ.get('DEFAULT_QUERIES', '[]')),
    'min_confidence': float(os.environ.get('MIN_CONFIDENCE', '80')),
    'salva_blocchi_grezzi': os.environ.get('SALVA_BLOCCHI_GREZZI', 'false').lower() == 'true',
}

# Textract puo' rispondere con throttling quando arrivano molti file insieme:
# si riprova qualche volta con attesa crescente prima di dichiarare l'errore.
ERRORI_RIPROVABILI = ('ThrottlingException', 'ProvisionedThroughputExceededException',
                      'LimitExceededException', 'InternalServerError')
TENTATIVI = 4


def _leggi_opzioni(bucket, key):
    """
    Rilegge le opzioni scritte dalla lambda presigned_url.

    Se il file non c'e' (immagine caricata da CLI o da console) si usano i
    default configurati in Terraform: l'analisi parte lo stesso.
    """
    nome_base = key.split('/')[-1]
    job_key = f"{JOBS_PREFIX}{nome_base}.json"

    try:
        risposta = s3_client.get_object(Bucket=bucket, Key=job_key)
        job = json.loads(risposta['Body'].read().decode('utf-8'))
        print(f"{key}: opzioni lette da {job_key}")
        return normalizza_opzioni(job.get('opzioni') or {}, OPZIONI_DEFAULT, MAX_QUERIES), job
    except ClientError as errore:
        if errore.response.get('Error', {}).get('Code') in ('NoSuchKey', '404'):
            print(f"{key}: nessun file opzioni, si usano i default")
            return normalizza_opzioni({}, OPZIONI_DEFAULT, MAX_QUERIES), {}
        raise
    except (ValueError, json.JSONDecodeError) as errore:
        print(f"{key}: file opzioni non valido ({errore}), si usano i default")
        return normalizza_opzioni({}, OPZIONI_DEFAULT, MAX_QUERIES), {}


def _queries_config(opzioni, per_pdf):
    """
    Costruisce QueriesConfig.

    Il campo Pages (query limitata ad alcune pagine) ha senso solo sui
    documenti multipagina: sulle immagini Textract lo rifiuta, quindi
    nella via sincrona viene semplicemente omesso.
    """
    elenco = []
    for query in opzioni['queries']:
        voce = {'Text': query['text'], 'Alias': query['alias']}
        if per_pdf and query.get('pages'):
            voce['Pages'] = query['pages']
        elenco.append(voce)
    return {'Queries': elenco}


def _job_tag(key):
    """JobTag leggibile nei log: Textract ammette lettere, cifre, punto, trattino, underscore e due punti (max 64 caratteri)."""
    ripulito = re.sub(r'[^a-zA-Z0-9_.\-:]', '_', key.split('/')[-1])
    return ripulito[-64:] or 'documento'


def _client_request_token(key, etag):
    """
    Token di idempotenza del job asincrono.

    Deriva da key + ETag, quindi identifica il singolo upload: se la Lambda
    viene ritentata (invocazione asincrona) Textract riconosce il token e NON
    avvia un secondo job, evitando di rianalizzare - e rifatturare - il PDF.
    """
    impronta = hashlib.sha256(f"{key}|{etag}".encode('utf-8')).hexdigest()
    return impronta[:64]


def _avvia_job_asincrono(bucket, key, opzioni, etag):
    """
    Avvia il job asincrono su un PDF e restituisce (JobId, nome operazione).

    Non attende il risultato: Textract pubblichera' su SNS a job concluso e
    sara' textract_collect a raccogliere i blocchi.
    """
    if not (SNS_TOPIC_ARN and TEXTRACT_ROLE_ARN):
        raise RuntimeError(
            "Analisi asincrona non configurata: mancano SNS_TOPIC_ARN o TEXTRACT_ROLE_ARN"
        )

    comuni = {
        'DocumentLocation': {'S3Object': {'Bucket': bucket, 'Name': key}},
        'NotificationChannel': {'SNSTopicArn': SNS_TOPIC_ARN, 'RoleArn': TEXTRACT_ROLE_ARN},
        'JobTag': _job_tag(key),
        'ClientRequestToken': _client_request_token(key, etag),
    }

    if not opzioni['feature_types']:
        risposta = textract.start_document_text_detection(**comuni)
        return risposta['JobId'], 'StartDocumentTextDetection'

    parametri = dict(comuni, FeatureTypes=opzioni['feature_types'])
    if 'QUERIES' in opzioni['feature_types']:
        parametri['QueriesConfig'] = _queries_config(opzioni, per_pdf=True)
    risposta = textract.start_document_analysis(**parametri)
    return risposta['JobId'], 'StartDocumentAnalysis'


def _chiama_textract(bucket, key, opzioni):
    """
    Chiama l'operazione sincrona di Textract adatta alle opzioni richieste.

    - nessuna feature          -> DetectDocumentText (solo testo, piu' economica)
    - una o piu' feature       -> AnalyzeDocument con FeatureTypes

    Vale solo per le immagini: accettano una pagina sola e rispondono subito.
    I PDF passano invece da _avvia_job_asincrono().
    """
    documento = {'S3Object': {'Bucket': bucket, 'Name': key}}
    feature_types = opzioni['feature_types']

    for tentativo in range(1, TENTATIVI + 1):
        try:
            if not feature_types:
                return textract.detect_document_text(Document=documento), 'DetectDocumentText'

            parametri = {'Document': documento, 'FeatureTypes': feature_types}
            if 'QUERIES' in feature_types:
                parametri['QueriesConfig'] = _queries_config(opzioni, per_pdf=False)
            return textract.analyze_document(**parametri), 'AnalyzeDocument'

        except ClientError as errore:
            codice = errore.response.get('Error', {}).get('Code', '')
            if codice in ERRORI_RIPROVABILI and tentativo < TENTATIVI:
                attesa = 2 ** tentativo
                print(f"{key}: {codice}, nuovo tentativo fra {attesa}s ({tentativo}/{TENTATIVI})")
                time.sleep(attesa)
                continue
            raise


def _salva_json(bucket, key_output, contenuto):
    s3_client.put_object(
        Bucket=bucket,
        Key=key_output,
        Body=json.dumps(contenuto, ensure_ascii=False, indent=2).encode('utf-8'),
        ContentType='application/json; charset=utf-8'
    )


def _analizza(bucket, key, size_bytes, etag=''):
    """Analizza un singolo documento e scrive il JSON di risultato su S3."""
    nome_base = key.split('/')[-1]
    key_output = f"{OUTPUT_PREFIX}{nome_base}.json"
    inizio = time.time()

    opzioni, job = _leggi_opzioni(bucket, key)

    # Nome originale scelto dall'utente: la key ha in piu' il prefisso temporale
    file_name = job.get('file_name') or nome_base
    pdf = e_pdf(key)

    risultato = {
        'file_name': file_name,
        'image_key': key,
        'bucket': bucket,
        'size_bytes': size_bytes or 0,
        'content_type': job.get('content_type') or ('application/pdf' if pdf else ''),
        'processed_at': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'uploaded_at': job.get('requested_at'),
        'opzioni': opzioni,
        'modalita': 'asincrona' if pdf else 'sincrona',
        'feature_types': opzioni['feature_types'],
        'stato': 'COMPLETATO',
        'error': None,
    }

    try:
        if pdf:
            # Via asincrona: qui si avvia soltanto il job. Il JSON definitivo
            # lo scrivera' textract_collect quando arrivera' la notifica SNS.
            job_id, api_usata = _avvia_job_asincrono(bucket, key, opzioni, etag)
            risultato['textract_api'] = api_usata
            risultato['job_id'] = job_id
            risultato['stato'] = 'IN_ELABORAZIONE'
            risultato['text'] = ''
            risultato['duration_ms'] = int((time.time() - inizio) * 1000)

            # JSON provvisorio: senza, la pagina web non avrebbe modo di
            # distinguere "job avviato" da "notifica S3 mai arrivata".
            _salva_json(bucket, key_output, risultato)
            print(f"{key}: job asincrono {job_id} avviato con {api_usata}, in attesa di SNS")
            return risultato

        risposta, api_usata = _chiama_textract(bucket, key, opzioni)
        risultato['textract_api'] = api_usata
        risultato.update(elabora_risposta(risposta, opzioni['min_confidence']))

        if opzioni['salva_blocchi_grezzi']:
            key_raw = f"{RAW_PREFIX}{nome_base}.raw.json"
            _salva_json(bucket, key_raw, {
                'file_name': file_name,
                'image_key': key,
                'textract_api': api_usata,
                'response': risposta,
            })
            risultato['raw_key'] = key_raw

        stats = risultato['stats']
        print(
            f"{key}: {api_usata} ok - {stats['n_lines']} righe, {stats['n_words']} parole, "
            f"{stats['n_tables']} tabelle, {stats['n_forms']} campi, "
            f"{stats['n_queries_answered']}/{stats['n_queries']} query risolte"
        )

    except ClientError as errore:
        codice = errore.response.get('Error', {}).get('Code', 'ClientError')
        messaggio = errore.response.get('Error', {}).get('Message', str(errore))
        risultato['stato'] = 'ERRORE'
        risultato['error'] = f"{codice}: {messaggio}"
        risultato['text'] = ''
        print(f"{key}: errore Textract {risultato['error']}")

    except Exception as errore:  # noqa: BLE001 - l'errore deve finire nel JSON
        risultato['stato'] = 'ERRORE'
        risultato['error'] = f"{type(errore).__name__}: {errore}"
        risultato['text'] = ''
        print(f"{key}: errore imprevisto {risultato['error']}")

    risultato['duration_ms'] = int((time.time() - inizio) * 1000)

    # Il JSON viene scritto sempre, anche in caso di errore: la pagina web
    # deve poter mostrare "ERRORE" invece di restare in attesa all'infinito.
    _salva_json(bucket, key_output, risultato)
    print(f"{key}: risultato salvato in {key_output} (stato {risultato['stato']})")

    return risultato


def lambda_handler(event, context):
    elaborati = []

    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        # La key arriva codificata (gli spazi diventano '+')
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        size_bytes = record['s3']['object'].get('size', 0)

        if not key.lower().endswith(ALLOWED_EXTENSIONS):
            print(f"Formato non supportato, file ignorato: {key}")
            continue

        # L'ETag identifica il contenuto caricato: serve a rendere idempotente
        # l'avvio del job asincrono in caso di retry della Lambda.
        etag = record['s3']['object'].get('eTag', '')

        risultato = _analizza(bucket, key, size_bytes, etag)
        elaborati.append({
            'image_key': key,
            'stato': risultato['stato'],
            'modalita': risultato['modalita'],
            'n_caratteri': len(risultato.get('text') or ''),
        })

    return {'elaborati': len(elaborati), 'dettaglio': elaborati}
