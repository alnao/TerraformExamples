# Setup SFTP - AWS Esempio 11

Guida alla configurazione della chiave RSA per la Lambda `sftp_send`.

## Requisiti

La Lambda usa la libreria `paramiko` per connettersi al server SFTP tramite autenticazione con chiave pubblica. La chiave privata deve essere:

- In formato **RSA classico (PEM)** — inizia con `-----BEGIN RSA PRIVATE KEY-----`
- Salvata in **SSM Parameter Store** come `SecureString`
- Accessibile dalla Lambda tramite il parametro configurato in `var.sftp_private_key_ssm_parameter`

## Step 1: Genera la coppia di chiavi RSA

```bash
# Genera chiave RSA 2048-bit in formato PEM
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""
```

Vengono creati due file:
- `sftp_key` — chiave privata (da caricare su SSM, **non committare su git**)
- `sftp_key.pub` — chiave pubblica (da aggiungere al server SFTP)

### Verifica il formato

La chiave privata deve iniziare con:

```
-----BEGIN RSA PRIVATE KEY-----
```

Se vedi invece `-----BEGIN OPENSSH PRIVATE KEY-----` (formato OpenSSH moderno), converti:

```bash
ssh-keygen -p -m PEM -f sftp_key
# Lascia la passphrase vuota quando richiesto
```

## Step 2: Carica la chiave privata su SSM Parameter Store

```bash
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value file://sftp_key \
  --type "SecureString" \
  --region eu-central-1
```

Verifica il caricamento:

```bash
aws ssm get-parameter \
  --name "/esempio-11/sftp/private-key" \
  --with-decryption \
  --query Parameter.Value \
  --output text | head -1
# Output atteso: -----BEGIN RSA PRIVATE KEY-----
```

## Step 3: Configura il server SFTP

Aggiungi la chiave pubblica al file `~/.ssh/authorized_keys` dell'utente SFTP sul server:

```bash
# Sul server SFTP (o tramite il pannello di amministrazione)
cat sftp_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

## Step 4: Ottieni la host key del server (consigliato)

Per abilitare la verifica dell'host key e prevenire attacchi MITM, recupera la chiave pubblica del server:

```bash
ssh-keyscan -t rsa sftp.example.com 2>/dev/null
# Output: sftp.example.com ssh-rsa AAAA...
```

Usa il valore `ssh-rsa AAAA...` (senza il nome host) come parametro `sftp_host_key` nelle chiamate API.

## Step 5: Test connessione

```bash
# Test locale con SSH
ssh -i sftp_key -o StrictHostKeyChecking=yes user@sftp.example.com

# Test via Lambda (dopo terraform apply)
curl -s -X POST $API_URL/sftp-send \
  -H "Content-Type: application/json" \
  -d '{
    "s3_key": "test.txt",
    "sftp_host": "sftp.example.com",
    "sftp_username": "user",
    "sftp_remote_path": "/incoming/test.txt",
    "sftp_host_key": "ssh-rsa AAAA..."
  }' | jq .
```

## Parametro sftp_host_key

Il campo `sftp_host_key` nella richiesta API è **opzionale ma fortemente consigliato** in produzione.

| Scenario | Comportamento Lambda |
|----------|---------------------|
| `sftp_host_key` fornita | Verifica host key prima di connettersi (`RejectPolicy`). Connessione rifiutata se non corrisponde. |
| `sftp_host_key` assente | Connessione accettata senza verifica (`WarningPolicy`). Log di warning nel CloudWatch. |

## Troubleshooting

### Errore: `Not a valid RSA private key file`

La chiave non è in formato RSA PEM. Rigenera con il flag `-m PEM`:

```bash
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""
```

### Errore: `Authentication failed`

1. Verifica che la chiave pubblica sia in `authorized_keys` sul server
2. Controlla i permessi: `authorized_keys` deve essere `600`, `.ssh` deve essere `700`
3. Testa la connessione locale: `ssh -i sftp_key -v user@host`
4. Verifica che il parametro SSM contenga la chiave corretta

### Errore: `Connection timed out`

1. Verifica che il server SFTP sia raggiungibile dalla Lambda (VPC, Security Group, firewall)
2. Controlla la porta (default 22): `sftp_port` nel body della richiesta
3. La Lambda non è in VPC per default — se il server SFTP è in una VPC privata, configurare VPC per la Lambda `sftp_send`

### Errore: `Host key verification failed`

La `sftp_host_key` fornita non corrisponde alla chiave del server. Aggiorna la chiave:

```bash
ssh-keyscan -t rsa sftp.example.com 2>/dev/null | awk '{print $2, $3}'
```

## Sicurezza

- **Non committare** `sftp_key` su git — aggiungere al `.gitignore`
- Usare sempre `SecureString` in SSM (cifrato con KMS)
- Ruotare la chiave periodicamente: genera una nuova coppia, aggiorna SSM e `authorized_keys`
- In produzione, fornire sempre `sftp_host_key` per prevenire MITM
- Limitare l'accesso al parametro SSM con policy IAM (già configurato: solo la Lambda `sftp_send` ha `ssm:GetParameter`)

## Aggiornamento della chiave

```bash
# 1. Genera nuova coppia
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key_new -N ""

# 2. Aggiungi nuova chiave pubblica al server (senza rimuovere la vecchia)
cat sftp_key_new.pub >> ~/.ssh/authorized_keys  # sul server SFTP

# 3. Aggiorna SSM con la nuova chiave privata
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value file://sftp_key_new \
  --type "SecureString" \
  --overwrite

# 4. Verifica che la Lambda funzioni con la nuova chiave
curl -s -X POST $API_URL/sftp-send \
  -H "Content-Type: application/json" \
  -d '{"s3_key":"test.txt","sftp_host":"...","sftp_username":"...","sftp_remote_path":"/test.txt"}' | jq .

# 5. Rimuovi la vecchia chiave pubblica dal server
# (modifica manualmente authorized_keys sul server SFTP)
```

## Alternative a SFTP con chiave RSA

Se la gestione delle chiavi è troppo complessa per il tuo caso d'uso:

- **AWS Transfer Family**: SFTP as a Service con integrazione S3 nativa, autenticazione IAM, CloudWatch logging
- **S3 Presigned URL**: per semplice upload/download senza server SFTP
- **SFTP con password**: modifica `sftp_send.py` per usare `transport.connect(username, password)` invece di `pkey`
