"""
Lambda 1 - detect_labels

Trigger: evento S3 ObjectCreated sulla cartella input/ del bucket immagini.

Flusso:
  1. legge la key dell'oggetto appena caricato
  2. chiama Rekognition DetectLabels per avere l'elenco degli elementi
  3. verifica se fra le label (o fra le loro categorie padre) compare la
     parola chiave configurata, per esempio "airplane"
  4. salva tutto su DynamoDB, con il campo immagine_rilevante = SI / NO
"""
import os
import re
import urllib.parse
from datetime import datetime, timezone
from decimal import Decimal

import boto3

from utils import ALLOWED_EXTENSIONS

rekognition = boto3.client('rekognition')
dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ['TABLE_NAME']
KEYWORD = os.environ.get('KEYWORD', 'airplane')
MIN_CONFIDENCE = float(os.environ.get('MIN_CONFIDENCE', '75'))
MAX_LABELS = int(os.environ.get('MAX_LABELS', '15'))

table = dynamodb.Table(TABLE_NAME)


def _match_keyword(labels, keyword):
    """
    Cerca la parola chiave fra i nomi delle label e fra le categorie padre
    restituite da Rekognition (per esempio la label "Boeing 747" ha come
    parent "Airplane"): confronto case-insensitive su parola intera, cosi'
    la keyword "car" non fa scattare il flag su "Cargo" o "Cartoon".

    Returns:
        (trovata: bool, confidenza: float) - confidenza 0 se non trovata.
    """
    keyword = keyword.strip().lower()
    if not keyword:
        return False, 0.0

    pattern = re.compile(r'\b' + re.escape(keyword) + r'\b', re.IGNORECASE)

    for label in labels:
        nomi = [label.get('Name', '')]
        nomi += [parent.get('Name', '') for parent in label.get('Parents', [])]
        if any(nome and pattern.search(nome) for nome in nomi):
            return True, float(label.get('Confidence', 0))

    return False, 0.0


def _analizza_immagine(bucket, key, size_bytes):
    """Analizza una singola immagine e scrive la riga su DynamoDB."""
    if not key.lower().endswith(ALLOWED_EXTENSIONS):
        print(f"Formato non supportato, file ignorato: {key}")
        return None

    risposta = rekognition.detect_labels(
        Image={'S3Object': {'Bucket': bucket, 'Name': key}},
        MaxLabels=MAX_LABELS,
        MinConfidence=MIN_CONFIDENCE
    )
    labels = risposta.get('Labels', [])
    print(f"{key}: trovate {len(labels)} label")

    trovata, confidenza = _match_keyword(labels, KEYWORD)

    item = {
        'image_key': key,
        'bucket': bucket,
        # I Decimal servono perche' DynamoDB non accetta i float
        'upload_timestamp': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'immagine_rilevante': 'SI' if trovata else 'NO',
        'keyword': KEYWORD,
        'keyword_confidence': Decimal(str(round(confidenza, 2))),
        'labels': [
            {
                'name': label['Name'],
                'confidence': Decimal(str(round(float(label['Confidence']), 2)))
            }
            for label in labels
        ],
        'labels_csv': ', '.join(label['Name'] for label in labels),
        'size_bytes': Decimal(str(size_bytes or 0)),
    }

    table.put_item(Item=item)
    print(f"{key}: immagine_rilevante = {item['immagine_rilevante']} (keyword '{KEYWORD}')")
    return item


def lambda_handler(event, context):
    elaborate = []

    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        # La key arriva codificata (gli spazi diventano '+')
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        size_bytes = record['s3']['object'].get('size', 0)

        try:
            item = _analizza_immagine(bucket, key, size_bytes)
            if item:
                elaborate.append({
                    'image_key': key,
                    'immagine_rilevante': item['immagine_rilevante'],
                    'labels': item['labels_csv']
                })
        except Exception as errore:
            # Si logga e si prosegue con gli altri record dell'evento
            print(f"Errore nell'analisi di {key}: {errore}")
            raise

    return {'elaborate': len(elaborate), 'dettaglio': elaborate}
