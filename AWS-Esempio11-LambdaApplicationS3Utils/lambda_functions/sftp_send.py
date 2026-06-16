import json
import boto3
import os
import io

from utils import log_operation, api_response

s3_client = boto3.client('s3')
ssm_client = boto3.client('ssm')

BUCKET_NAME = os.environ['BUCKET_NAME']
LOGS_TABLE = os.environ['DYNAMODB_LOGS_TABLE']
SFTP_PRIVATE_KEY_PARAM = os.environ['SFTP_PRIVATE_KEY_PARAM']

# Cache chiave privata per riuso tra invocazioni warm
_private_key_cache = None


def get_sftp_private_key() -> str:
    """
    Recupera la chiave privata SFTP da SSM Parameter Store.
    Usa una cache in-memory per le invocazioni warm.
    """
    global _private_key_cache
    if _private_key_cache is not None:
        return _private_key_cache

    response = ssm_client.get_parameter(
        Name=SFTP_PRIVATE_KEY_PARAM,
        WithDecryption=True
    )
    _private_key_cache = response['Parameter']['Value']
    return _private_key_cache


def lambda_handler(event, context):
    """
    Invia un file da S3 a un server SFTP tramite autenticazione con chiave RSA.

    NOTA: Richiede Lambda Layer con paramiko installato.
    Vedi variabile Terraform: lambda_layer_arns_sftp

    La chiave privata RSA deve essere salvata in SSM Parameter Store come SecureString.
    Vedi SFTP_SETUP.md per le istruzioni di configurazione.

    Input (body JSON):
    {
        "s3_key": "path/to/file.txt",
        "sftp_host": "sftp.example.com",
        "sftp_port": 22,              # opzionale, default 22
        "sftp_username": "user",
        "sftp_remote_path": "/upload/file.txt",
        "sftp_host_key": "ssh-rsa AAAA..."  # opzionale ma consigliato per verifica host
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        s3_key = body.get('s3_key')
        sftp_host = body.get('sftp_host')
        sftp_port = int(body.get('sftp_port', 22))
        sftp_username = body.get('sftp_username')
        sftp_remote_path = body.get('sftp_remote_path')
        sftp_host_key_str = body.get('sftp_host_key')  # Opzionale: chiave pubblica host per verifica

        if not all([s3_key, sftp_host, sftp_username, sftp_remote_path]):
            return api_response(400, {
                'error': 'Parametri mancanti',
                'required': ['s3_key', 'sftp_host', 'sftp_username', 'sftp_remote_path']
            })

        # Scarica file da S3
        s3_obj = s3_client.get_object(Bucket=BUCKET_NAME, Key=s3_key)
        file_content = s3_obj['Body'].read()

        try:
            import paramiko
        except ImportError:
            error_msg = 'paramiko non trovato. Aggiungere un Lambda Layer con paramiko installato.'
            log_operation(LOGS_TABLE, 'sftp_send', {'error': error_msg}, 'error')
            return api_response(500, {
                'error': error_msg,
                'suggestion': 'Creare un layer con: pip install paramiko -t python/ && zip -r layer.zip python/'
            })

        # Carica chiave privata
        private_key_str = get_sftp_private_key()
        private_key = paramiko.RSAKey.from_private_key(io.StringIO(private_key_str))

        # Connessione SFTP tramite SSHClient (gestisce host key verification)
        ssh_client = paramiko.SSHClient()

        if sftp_host_key_str:
            # Usa la chiave host fornita esplicitamente (consigliato in produzione)
            import base64
            key_parts = sftp_host_key_str.split(' ', 2)
            if len(key_parts) >= 2:
                key_type, key_data = key_parts[0], key_parts[1]
                host_key = paramiko.RSAKey(data=base64.b64decode(key_data))
                ssh_client.get_host_keys().add(sftp_host, key_type, host_key)
            # Rifiuta connessioni con host key non corrispondente
            ssh_client.set_missing_host_key_policy(paramiko.RejectPolicy())
        else:
            # Nessuna chiave host fornita: accetta ma logga un warning
            print(f"WARNING: sftp_host_key non fornita per {sftp_host}. "
                  "La connessione è vulnerabile a MITM. Fornire sftp_host_key in produzione.")
            ssh_client.set_missing_host_key_policy(paramiko.WarningPolicy())

        try:
            ssh_client.connect(
                hostname=sftp_host,
                port=sftp_port,
                username=sftp_username,
                pkey=private_key,
                timeout=30
            )
            sftp = ssh_client.open_sftp()
            sftp.putfo(io.BytesIO(file_content), sftp_remote_path)
            sftp.close()
        finally:
            ssh_client.close()

        log_operation(
            LOGS_TABLE,
            'sftp_send',
            {
                's3_key': s3_key,
                'sftp_host': sftp_host,
                'sftp_remote_path': sftp_remote_path,
                'file_size': len(file_content),
                'host_key_verified': sftp_host_key_str is not None
            }
        )

        return api_response(200, {
            'message': 'File inviato via SFTP con successo',
            's3_key': s3_key,
            'sftp_remote_path': sftp_remote_path,
            'file_size': len(file_content)
        })

    except Exception as e:
        log_operation(LOGS_TABLE, 'sftp_send', {'error': str(e)}, 'error')
        return api_response(500, {'error': str(e)})
