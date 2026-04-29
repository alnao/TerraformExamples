#!/usr/bin/env python3
"""
Test script per Azure CosmosDB MongoDB vCore (Esempio 09).

Recupera automaticamente la connection string da:
  1. Terraform output (se disponibile nella cartella corrente)
  2. Azure Key Vault (tramite Azure CLI)
  3. Variabile d'ambiente COSMOSDB_CONNECTION_STRING
  4. Parametro da riga di comando --connection-string

Uso:
  python3 test.py                          # Inserisce un documento e mostra risultati (default)
  python3 test.py --list                   # Lista databases e collections
  python3 test.py --insert                 # Inserisce un documento di prova
  python3 test.py --find                   # Cerca documenti nella collection
  python3 test.py --drop                   # Elimina la collection di test
  python3 test.py -c "mongodb+srv://..."   # Connection string manuale
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

try:
    from pymongo import MongoClient
    from pymongo.errors import ConnectionFailure, OperationFailure
except ImportError:
    print("Errore: pymongo non installato. Esegui: pip install pymongo")
    sys.exit(1)


# ── Costanti di default (allineate con variables.tf) ──────────────────────────
DEFAULT_DATABASE_NAME   = "esempio09db"
DEFAULT_COLLECTION_NAME = "annotazioni"
DEFAULT_KEY_VAULT_NAME  = "alnao-terraform-es9-key"
DEFAULT_SECRET_NAME     = "cosmosdb-mongodb-connection-string"


def get_connection_string_from_terraform() -> str | None:
    """Recupera la connection string dall'output Terraform."""
    try:
        result = subprocess.run(
            ["terraform", "output", "-json", "cosmosdb_connection_strings"],
            capture_output=True, text=True, timeout=30,
            cwd=os.path.dirname(os.path.abspath(__file__)) or ".",
        )
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout.strip())
            if isinstance(data, list) and len(data) > 0:
                return data[0]
            elif isinstance(data, str):
                try:
                    parsed = json.loads(data)
                    if isinstance(parsed, list) and len(parsed) > 0:
                        return parsed[0]
                except (json.JSONDecodeError, TypeError):
                    return data
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        pass
    return None


def get_connection_string_from_keyvault(
    vault_name: str = DEFAULT_KEY_VAULT_NAME,
    secret_name: str = DEFAULT_SECRET_NAME,
) -> str | None:
    """Recupera la connection string da Azure Key Vault tramite Azure CLI."""
    try:
        result = subprocess.run(
            [
                "az", "keyvault", "secret", "show",
                "--vault-name", vault_name,
                "--name", secret_name,
                "--query", "value",
                "-o", "tsv",
            ],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0 and result.stdout.strip():
            value = result.stdout.strip()
            try:
                parsed = json.loads(value)
                if isinstance(parsed, list) and len(parsed) > 0:
                    return parsed[0]
                elif isinstance(parsed, str):
                    return parsed
            except (json.JSONDecodeError, TypeError):
                return value
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def resolve_connection_string(manual_cs: str | None = None, vault_name: str = DEFAULT_KEY_VAULT_NAME) -> str:
    """
    Risolve la connection string nell'ordine di priorità:
      1. Parametro manuale (--connection-string)
      2. Variabile d'ambiente COSMOSDB_CONNECTION_STRING
      3. terraform output cosmosdb_connection_strings
      4. Azure Key Vault (az keyvault secret show)
    """
    if manual_cs:
        print("[info] Uso connection string da parametro CLI.")
        return manual_cs

    env_cs = os.environ.get("COSMOSDB_CONNECTION_STRING")
    if env_cs:
        print("[info] Uso connection string da variabile d'ambiente COSMOSDB_CONNECTION_STRING.")
        return env_cs

    print("[info] Tentativo recupero connection string da Terraform output ...")
    tf_cs = get_connection_string_from_terraform()
    if tf_cs:
        print("[info] Connection string recuperata da Terraform output.")
        return tf_cs

    print("[info] Tentativo recupero connection string da Azure Key Vault ...")
    kv_cs = get_connection_string_from_keyvault(vault_name)
    if kv_cs:
        print("[info] Connection string recuperata da Azure Key Vault.")
        return kv_cs

    print(
        "\nErrore: impossibile recuperare la connection string automaticamente.\n"
        "Opzioni:\n"
        "  1. Esegui 'terraform apply' nella cartella corrente\n"
        "  2. Imposta la variabile COSMOSDB_CONNECTION_STRING\n"
        "  3. Usa --connection-string <stringa>\n"
        "  4. Assicurati che Azure CLI sia configurato (az login)\n"
    )
    sys.exit(1)


# ── Operazioni sul database ──────────────────────────────────────────────────

def cmd_list(client: MongoClient) -> None:
    """Lista tutti i database e le relative collections."""
    print("\n=== Database disponibili ===")
    for db_name in client.list_database_names():
        db = client[db_name]
        collections = db.list_collection_names()
        print(f"  📦 {db_name}")
        for coll in collections:
            count = db[coll].estimated_document_count()
            print(f"      └─ {coll}  ({count} documenti)")
    print()


def cmd_insert(client: MongoClient, db_name: str, coll_name: str) -> None:
    """Inserisce un documento di prova."""
    db  = client[db_name]
    col = db[coll_name]
    doc = {
        "tipo":       "annotazione",
        "testo":      "Documento di prova inserito da test.py",
        "creato_il":  datetime.now(timezone.utc).isoformat(),
        "fonte":      "test.py",
    }
    result = col.insert_one(doc)
    print(f"\nDocumento inserito con _id: {result.inserted_id}")
    print(f"  Database:   {db_name}")
    print(f"  Collection: {coll_name}")
    print(f"  Documento:  {json.dumps(doc, default=str, indent=2)}\n")


def cmd_find(client: MongoClient, db_name: str, coll_name: str) -> None:
    """Mostra tutti i documenti nella collection (max 20)."""
    db   = client[db_name]
    col  = db[coll_name]
    docs = list(col.find().limit(20))
    print(f"\n=== Documenti in {db_name}.{coll_name} ({len(docs)} mostrati, max 20) ===")
    for doc in docs:
        doc["_id"] = str(doc["_id"])
        print(f"  {json.dumps(doc, default=str, ensure_ascii=False)}")
    if not docs:
        print("  (nessun documento trovato)")
    print()


def cmd_drop(client: MongoClient, db_name: str, coll_name: str) -> None:
    """Elimina la collection."""
    client[db_name].drop_collection(coll_name)
    print(f"\nCollection '{coll_name}' eliminata dal database '{db_name}'.\n")


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Test CosmosDB MongoDB vCore (Esempio 09)"
    )
    parser.add_argument("--connection-string", "-c", default=None,
                        help="Connection string MongoDB (sovrascrive auto-detect)")
    parser.add_argument("--database", "-d", default=DEFAULT_DATABASE_NAME,
                        help=f"Nome del database (default: {DEFAULT_DATABASE_NAME})")
    parser.add_argument("--collection", default=DEFAULT_COLLECTION_NAME,
                        help=f"Nome della collection (default: {DEFAULT_COLLECTION_NAME})")
    parser.add_argument("--vault-name", default=DEFAULT_KEY_VAULT_NAME,
                        help=f"Nome del Key Vault (default: {DEFAULT_KEY_VAULT_NAME})")

    group = parser.add_mutually_exclusive_group()
    group.add_argument("--list",   action="store_true", help="Lista database e collections")
    group.add_argument("--insert", action="store_true", help="Inserisce un documento di prova")
    group.add_argument("--find",   action="store_true", help="Mostra documenti nella collection")
    group.add_argument("--drop",   action="store_true", help="Elimina la collection")

    args = parser.parse_args()

    connection_string = resolve_connection_string(args.connection_string, args.vault_name)

    print(f"[info] Connessione al cluster MongoDB ...")
    try:
        client = MongoClient(connection_string, serverSelectionTimeoutMS=10000)
        client.admin.command("ping")
        print("[info] Connessione riuscita!\n")
    except ConnectionFailure as e:
        print(f"\nErrore di connessione: {e}")
        print("Verifica che:")
        print("  - Il cluster sia attivo (az cosmosdb mongocluster list ...)")
        print("  - La regola firewall consenta il tuo IP")
        print("  - La connection string sia corretta")
        sys.exit(1)
    except OperationFailure as e:
        print(f"\nErrore di autenticazione: {e}")
        sys.exit(1)

    try:
        if args.list:
            cmd_list(client)
        elif args.insert:
            cmd_insert(client, args.database, args.collection)
        elif args.find:
            cmd_find(client, args.database, args.collection)
        elif args.drop:
            cmd_drop(client, args.database, args.collection)
        else:
            # Default: insert + find (come lambda_handler che salva e logga)
            cmd_insert(client, args.database, args.collection)
            cmd_find(client, args.database, args.collection)
    finally:
        client.close()
        print("[info] Connessione chiusa.")


if __name__ == "__main__":
    main()
