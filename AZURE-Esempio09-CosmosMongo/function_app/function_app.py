"""
Azure Function App — Blob Trigger → CosmosDB MongoDB
Equivalente Azure di lambda_s3_to_dynamodb.py (AWS-Esempio09)

Mapping AWS → Azure:
  S3 Bucket          → Azure Blob Storage (container "uploads")
  Lambda Trigger     → Blob Trigger binding
  DynamoDB.put_item  → PyMongo collection.insert_one / replace_one
  CloudWatch logs    → Application Insights / logging module
  IAM Role           → System Managed Identity

Il trigger si attiva ad ogni blob creato nel container "uploads".
Salva i metadati del blob nella collection MongoDB specificata.
"""

import azure.functions as func
import logging
import json
import os
from datetime import datetime, timezone

try:
    from pymongo import MongoClient
    from pymongo.errors import PyMongoError
except ImportError:
    logging.error("pymongo non installato. Aggiungi 'pymongo>=4.0' a requirements.txt")
    raise

app = func.FunctionApp()


def get_mongo_client() -> MongoClient:
    """Crea e restituisce un client MongoDB dalla connection string dell'environment."""
    connection_string = os.environ.get("COSMOSDB_CONNECTION_STRING", "")
    if not connection_string:
        raise ValueError("COSMOSDB_CONNECTION_STRING non configurata")
    return MongoClient(connection_string, serverSelectionTimeoutMS=10000)


@app.blob_trigger(
    arg_name="myblob",
    path="uploads/{name}",
    connection="AzureWebJobsStorage",
)
def blob_to_cosmosdb(myblob: func.InputStream, name: str) -> None:
    """
    Trigger quando viene caricato un blob nel container 'uploads'.
    Salva i metadati del blob in CosmosDB MongoDB.

    Equivalente a lambda_handler in lambda_s3_to_dynamodb.py (AWS-Esempio09):
      - event['detail']['bucket']['name'] → container_name (da env BLOB_CONTAINER_NAME)
      - event['detail']['object']['key']  → name (blob name, da path binding)
      - event['detail']['object']['size'] → myblob.length
    """
    logging.info(f"[blob_to_cosmosdb] Trigger: blob='{name}', size={myblob.length} bytes")

    db_name   = os.environ.get("COSMOSDB_DATABASE", "esempio09db")
    coll_name = os.environ.get("COSMOSDB_COLLECTION", "blob_metadata")

    try:
        blob_content_preview = None
        if myblob.length and myblob.length <= 512:
            try:
                raw = myblob.read(512)
                blob_content_preview = raw.decode("utf-8", errors="replace")
            except Exception:
                blob_content_preview = "<non leggibile>"

        # Documento da salvare in CosmosDB (≈ item DynamoDB in lambda_s3_to_dynamodb.py)
        doc = {
            "id": name,                                          # Primary key (≈ DynamoDB hash_key)
            "blob_name": name,
            "file_name": name.split("/")[-1],                   # Solo nome file (≈ fileName)
            "file_path": name,                                   # Path completo (≈ filePath)
            "file_size": myblob.length,                         # In bytes (≈ fileSize)
            "container": os.environ.get("BLOB_CONTAINER_NAME", "uploads"),
            "event_type": "BlobCreated",                        # (≈ eventType)
            "processed_at": datetime.now(timezone.utc).isoformat(),  # (≈ processedAt)
            "content_preview": blob_content_preview,
        }

        # Salva in CosmosDB (replace_one con upsert = equivalente a DynamoDB PutItem)
        client = get_mongo_client()
        db     = client[db_name]
        coll   = db[coll_name]
        result = coll.replace_one({"id": name}, doc, upsert=True)
        client.close()

        if result.upserted_id:
            logging.info(f"[blob_to_cosmosdb] ✓ Inserito nuovo documento _id={result.upserted_id}")
        else:
            logging.info(f"[blob_to_cosmosdb] ✓ Aggiornato documento esistente per blob='{name}'")

        logging.info(
            f"[blob_to_cosmosdb] Salvato in {db_name}.{coll_name}: "
            f"blob='{name}', size={myblob.length} bytes"
        )

    except PyMongoError as e:
        logging.error(f"[blob_to_cosmosdb] ✗ Errore MongoDB: {e}")
        # Non rilanciare l'eccezione per evitare retry loop (come in lambda_s3_to_dynamodb.py)

    except Exception as e:
        logging.error(f"[blob_to_cosmosdb] ✗ Errore generico: {e}")
