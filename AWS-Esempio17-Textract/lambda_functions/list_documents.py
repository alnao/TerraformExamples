"""
Lambda 3 - list_documents

Trigger: GET /documents

Parametri di query string:
    limit=50            numero massimo di documenti restituiti (max 200)
    stato=tutti         tutti | completati | in_corso | errore
    q=fattura           filtro testuale su nome file e testo estratto
    key=input/xxx.png   restituisce il singolo documento con il JSON completo

Come funziona l'unione fra documenti e risultati:
  1. si elencano immagini e PDF sotto input/
  2. si elencano una volta sola le key presenti sotto output/
  3. per ogni immagine si cerca output/<nome file>.json

Se il JSON non c'e' ancora, il documento e' semplicemente "IN CORSO": e' il
comportamento normale nei primi secondi dopo l'upload, visto che l'analisi
gira in modo asincrono. Sui PDF esiste uno stato intermedio in piu',
"IN_ELABORAZIONE": il job Textract e' partito e sta girando, ma la notifica
SNS di fine lavoro non e' ancora arrivata. Nessuna riga resta appesa: le
lambda scrivono un JSON anche quando Textract fallisce.

Per ogni documento vengono aggiunti due presigned URL di breve durata:
preview_url per l'anteprima dell'immagine e json_url per scaricare il
risultato completo, senza mai rendere pubblico il bucket.
"""
import json
import os

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from utils import ALLOWED_EXTENSIONS, api_response, e_pdf

AWS_REGION = os.environ.get('AWS_REGION', 'eu-central-1')

s3_client = boto3.client(
    's3',
    region_name=AWS_REGION,
    config=Config(signature_version='s3v4', s3={'addressing_style': 'virtual'})
)

BUCKET_NAME = os.environ['BUCKET_NAME']
INPUT_PREFIX = os.environ.get('INPUT_PREFIX', 'input/')
OUTPUT_PREFIX = os.environ.get('OUTPUT_PREFIX', 'output/')
PREVIEW_EXPIRE = int(os.environ.get('PREVIEW_EXPIRE', '900'))

LIMIT_DEFAULT = 50
LIMIT_MAX = 200

# Nell'elenco il testo viene troncato: il JSON completo resta scaricabile da
# json_url o richiamabile con ?key=<image_key>
MAX_TESTO_ELENCO = 20000

# Oggetti scansionati al massimo sotto input/: evita che una lambda a 30s
# vada in timeout su un bucket con decine di migliaia di file.
MAX_OGGETTI_SCANSIONATI = 5000


def _presigned(key, expire=PREVIEW_EXPIRE):
    """Presigned URL GET per anteprima immagine o download del JSON."""
    try:
        return s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': BUCKET_NAME, 'Key': key},
            ExpiresIn=expire
        )
    except Exception as errore:  # noqa: BLE001 - un URL mancante non deve rompere l'elenco
        print(f"Presigned URL non disponibile per {key}: {errore}")
        return None


def _elenca(prefix, solo_documenti=False):
    """Elenca gli oggetti di un prefisso gestendo la paginazione."""
    oggetti = []
    paginator = s3_client.get_paginator('list_objects_v2')

    for pagina in paginator.paginate(Bucket=BUCKET_NAME, Prefix=prefix):
        for oggetto in pagina.get('Contents', []):
            key = oggetto['Key']
            if key.endswith('/'):
                continue
            if solo_documenti and not key.lower().endswith(ALLOWED_EXTENSIONS):
                continue
            oggetti.append(oggetto)
        if len(oggetti) >= MAX_OGGETTI_SCANSIONATI:
            print(f"Raggiunto il limite di {MAX_OGGETTI_SCANSIONATI} oggetti su {prefix}")
            break

    return oggetti


def _leggi_risultato(key_json):
    """Legge e decodifica il JSON prodotto dalla lambda di analisi."""
    try:
        risposta = s3_client.get_object(Bucket=BUCKET_NAME, Key=key_json)
        return json.loads(risposta['Body'].read().decode('utf-8'))
    except ClientError as errore:
        print(f"JSON non leggibile {key_json}: {errore}")
        return None
    except json.JSONDecodeError as errore:
        print(f"JSON non valido {key_json}: {errore}")
        return None


def _compatta(risultato):
    """
    Versione alleggerita del risultato per l'elenco.

    Si tolgono 'lines' e 'layout' (le parti piu' voluminose, con le coordinate
    di ogni riga) e si tronca il testo: il contenuto integrale resta comunque
    disponibile su json_url e con ?key=<image_key>.
    """
    compatto = {
        chiave: valore
        for chiave, valore in risultato.items()
        if chiave not in ('lines', 'layout')
    }

    testo = risultato.get('text') or ''
    if len(testo) > MAX_TESTO_ELENCO:
        compatto['text'] = testo[:MAX_TESTO_ELENCO]
        compatto['text_truncated'] = True
    else:
        compatto['text_truncated'] = False

    compatto['n_layout'] = len(risultato.get('layout') or [])
    return compatto


def _documento(oggetto, key_output_presenti, completo=False):
    """Costruisce la riga dell'elenco unendo immagine e risultato."""
    key = oggetto['Key']
    nome_base = key.split('/')[-1]
    key_json = f"{OUTPUT_PREFIX}{nome_base}.json"

    documento = {
        'image_key': key,
        'file_name': nome_base,
        # I PDF non si possono mostrare in un tag <img>: la pagina web usa
        # questo flag per disegnare un'icona con il link al file firmato.
        'is_pdf': e_pdf(key),
        'size_bytes': oggetto.get('Size', 0),
        'uploaded_at': oggetto['LastModified'].isoformat(timespec='seconds'),
        'preview_url': _presigned(key),
        'stato': 'IN_CORSO',
        'job_id': None,
        'json_key': None,
        'json_url': None,
        'risultato': None,
    }

    if key_json not in key_output_presenti:
        return documento

    risultato = _leggi_risultato(key_json)
    if risultato is None:
        documento['stato'] = 'ERRORE'
        documento['error'] = 'Il JSON di risultato non e\' leggibile'
        return documento

    documento['json_key'] = key_json
    documento['json_url'] = _presigned(key_json)
    # Su un PDF il primo JSON scritto e' provvisorio (IN_ELABORAZIONE): il job
    # asincrono e' partito ma Textract non ha ancora notificato la fine.
    documento['stato'] = risultato.get('stato', 'COMPLETATO')
    documento['error'] = risultato.get('error')
    documento['file_name'] = risultato.get('file_name') or nome_base
    documento['job_id'] = risultato.get('job_id')
    documento['modalita'] = risultato.get('modalita')
    documento['risultato'] = risultato if completo else _compatta(risultato)

    return documento


def _filtro_testo(documento, ricerca):
    """Ricerca case-insensitive su nome file e testo estratto."""
    if not ricerca:
        return True
    risultato = documento.get('risultato') or {}
    da_cercare = ' '.join([
        documento.get('file_name') or '',
        documento.get('image_key') or '',
        risultato.get('text') or '',
    ]).lower()
    return ricerca in da_cercare


# Un documento in attesa puo' trovarsi in due stati diversi: IN_CORSO (la
# Lambda di analisi non ha ancora scritto nulla) oppure IN_ELABORAZIONE (job
# asincrono sul PDF avviato, notifica SNS non ancora arrivata). Il filtro
# "in_corso" li comprende entrambi, cosi' l'utente non deve conoscere la
# differenza fra le due vie.
STATI_AMMESSI = {
    'tutti': None,
    'completati': ('COMPLETATO',),
    'in_corso': ('IN_CORSO', 'IN_ELABORAZIONE'),
    'errore': ('ERRORE',),
}


def _singolo_documento(key_richiesta):
    """Restituisce un solo documento con il JSON completo (nessun troncamento)."""
    # La key arriva dal client: deve restare dentro la cartella delle immagini
    if not key_richiesta.startswith(INPUT_PREFIX) or '..' in key_richiesta:
        return api_response(400, {'error': "Il parametro 'key' non e' valido"})

    try:
        testa = s3_client.head_object(Bucket=BUCKET_NAME, Key=key_richiesta)
    except ClientError:
        return api_response(404, {'error': f"Documento non trovato: {key_richiesta}"})

    nome_base = key_richiesta.split('/')[-1]
    key_json = f"{OUTPUT_PREFIX}{nome_base}.json"
    presenti = set()
    try:
        s3_client.head_object(Bucket=BUCKET_NAME, Key=key_json)
        presenti.add(key_json)
    except ClientError:
        pass

    oggetto = {'Key': key_richiesta, 'Size': testa.get('ContentLength', 0),
               'LastModified': testa['LastModified']}
    return api_response(200, {'item': _documento(oggetto, presenti, completo=True)})


def lambda_handler(event, context):
    parametri = event.get('queryStringParameters') or {}

    # ---- modalita' singolo documento ----
    key_richiesta = parametri.get('key')
    if key_richiesta:
        try:
            return _singolo_documento(key_richiesta)
        except Exception as errore:  # noqa: BLE001
            print(f"Errore nella lettura di {key_richiesta}: {errore}")
            return api_response(500, {'error': str(errore)})

    # ---- modalita' elenco ----
    try:
        limit = int(parametri.get('limit', LIMIT_DEFAULT))
    except (TypeError, ValueError):
        limit = LIMIT_DEFAULT
    limit = max(1, min(limit, LIMIT_MAX))

    stato_richiesto = str(parametri.get('stato', 'tutti')).lower()
    if stato_richiesto not in STATI_AMMESSI:
        return api_response(400, {
            'error': f"Valore 'stato' non valido: ammessi {', '.join(STATI_AMMESSI)}"
        })
    filtro_stato = STATI_AMMESSI[stato_richiesto]
    ricerca = str(parametri.get('q') or '').strip().lower()

    try:
        documenti_s3 = _elenca(INPUT_PREFIX, solo_documenti=True)
        key_output_presenti = {o['Key'] for o in _elenca(OUTPUT_PREFIX)}
    except Exception as errore:  # noqa: BLE001
        print(f"Errore nella lettura del bucket: {errore}")
        return api_response(500, {'error': str(errore)})

    # Dal piu' recente al piu' vecchio
    documenti_s3.sort(key=lambda o: o['LastModified'], reverse=True)

    totale_caricate = len(documenti_s3)
    documenti = []

    # Con un filtro attivo si scorre oltre il limite finche' non si riempie
    # la pagina, ma senza mai leggere piu' JSON del necessario.
    for oggetto in documenti_s3:
        if len(documenti) >= limit:
            break
        documento = _documento(oggetto, key_output_presenti)
        if filtro_stato and documento['stato'] not in filtro_stato:
            continue
        if not _filtro_testo(documento, ricerca):
            continue
        documenti.append(documento)

    in_attesa = STATI_AMMESSI['in_corso']
    in_corso = sum(1 for d in documenti if d['stato'] in in_attesa)

    return api_response(200, {
        'bucket': BUCKET_NAME,
        'stato': stato_richiesto,
        'q': ricerca,
        'count': len(documenti),
        'totale_caricate': totale_caricate,
        'totale_elaborate': len(key_output_presenti),
        'in_corso': in_corso,
        'items': documenti,
    })
