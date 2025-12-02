# Setup SFTP Private Key

## Generazione Chiave RSA

La Lambda per SFTP richiede una chiave privata in formato RSA classico (non OpenSSH).

### Step 1: Genera Chiave

```bash
# Genera coppia di chiavi RSA in formato PEM
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""
```

Questo comando genera due file:
- `sftp_key` - Chiave privata (da caricare su SSM)
- `sftp_key.pub` - Chiave pubblica (da fornire al server SFTP)

### Step 2: Verifica Formato

La chiave privata deve iniziare con:
```
-----BEGIN RSA PRIVATE KEY-----
```

Se vedi invece:
```
-----BEGIN OPENSSH PRIVATE KEY-----
```

Converti con:
```bash
ssh-keygen -p -m PEM -f sftp_key
```

### Step 3: Carica su SSM Parameter Store

```bash
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value file://sftp_key \
  --type "SecureString" \
  --region eu-central-1
```

### Step 4: Verifica Caricamento

```bash
aws ssm get-parameter \
  --name "/esempio-11/sftp/private-key" \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

### Step 5: Configura Server SFTP

Aggiungi la chiave pubblica (`sftp_key.pub`) al file `~/.ssh/authorized_keys` del server SFTP:

```bash
# Sul server SFTP
cat sftp_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Test Connessione

```bash
# Test locale
ssh -i sftp_key username@sftp.example.com

# Test via Lambda (dopo deploy)
curl -X POST https://YOUR_API_URL/v1/sftp-send \
  -H "Content-Type: application/json" \
  -d '{
    "s3_key": "test.txt",
    "sftp_host": "sftp.example.com",
    "sftp_username": "username",
    "sftp_remote_path": "/upload/test.txt"
  }'
```

## Troubleshooting

### Errore "Invalid key format"

La chiave non è in formato RSA PEM. Rigenera con:
```bash
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""
```

### Errore "Authentication failed"

1. Verifica username e host
2. Controlla che chiave pubblica sia su server
3. Verifica permessi authorized_keys (600)
4. Test con ssh diretto

### Errore "Connection timeout"

1. Verifica firewall/security group
2. Controlla porta (default 22)
3. Verifica host raggiungibile da Lambda

## Sicurezza

⚠️ **IMPORTANTE**:
- NON committare `sftp_key` su git
- Usa sempre SecureString in SSM
- Ruota chiavi regolarmente
- Limita accesso SSM parameter con IAM
- Considera AWS Transfer Family come alternativa

## Formato Chiave Richiesto

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
[contenuto chiave]
...
-----END RSA PRIVATE KEY-----
```

## Alternative

### AWS Transfer Family

Considera AWS Transfer Family (SFTP as a Service) invece di server esterno:
- Gestione AWS
- Integrazione S3 nativa
- Autenticazione IAM
- CloudWatch logging

### S3 Presigned URL

Per semplice upload/download, considera presigned URL invece di SFTP:
- Più semplice
- Nessuna chiave da gestire
- Integrazione S3 diretta
