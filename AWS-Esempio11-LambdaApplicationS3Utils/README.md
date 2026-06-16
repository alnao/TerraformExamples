# AWS Esempio 11 - Lambda Application S3 Utils

Applicazione serverless completa per gestione file S3 con elaborazione automatica, integrazione RDS, SFTP e API REST.

## Caratteristiche

### Architettura
- **S3 Bucket** con accesso pubblico opt-in (disabilitato per default)
- **9 Lambda Functions** per elaborazione file, con modulo condiviso `utils.py`
- **2 DynamoDB Tables** per log e scansione file
- **RDS Aurora MySQL** per storage dati relazionali (opzionale)
- **API Gateway REST** con 8 endpoint e CORS configurato
- **EventBridge** per orchestrazione e scheduling
- **VPC Endpoints** Gateway gratuiti per S3 e DynamoDB (accesso dalla Lambda in VPC)
- **Secrets Manager** per backup credenziali RDS (credenziali passate come env vars Lambda)
- **SSM Parameter Store** per chiave SFTP
- **CloudWatch** con alarms e logging
- **IAM** con policy granulari (least privilege)

### Funzionalità Lambda

| # | Nome | Trigger | Descrizione |
|---|------|---------|-------------|
| 1 | `presigned_url` | API POST | Genera URL firmati per upload file su S3 |
| 2 | `extract_zip` | API POST / EventBridge | Estrae file ZIP e li carica su S3 |
| 3 | `excel_to_csv` | API POST | Converte file Excel (.xlsx/.xls) in CSV |
| 4 | `upload_to_rds` | API POST | Carica dati CSV su Aurora MySQL |
| 5 | `read_from_rds` | API GET | Legge dati da tabelle RDS con paginazione |
| 6 | `sftp_send` | API POST | Invia file da S3 a server SFTP via chiave RSA |
| 7 | `s3_scan` | EventBridge (cron) | Scansione giornaliera bucket S3 → DynamoDB |
| 8 | `list_files` | API GET | Elenco file scansionati per data |
| 9 | `search_files` | API GET | Ricerca file per nome |

## Struttura

```
AWS-Esempio11-LambdaApplicationS3Utils/
├── backend.tf              # S3 backend per tfstate
├── variables.tf            # Variabili configurabili
├── main.tf                 # Provider, locals, CloudWatch log groups
├── s3.tf                   # S3 bucket, versioning, public access
├── dynamodb.tf             # DynamoDB tables (logs, scan)
├── rds.tf                  # RDS Aurora, Secrets Manager, VPC, Security Groups
├── iam.tf                  # IAM roles e policies per Lambda
├── lambda.tf               # Lambda functions e archivi ZIP
├── api_gateway.tf          # API Gateway REST
├── api_gateway_cors.tf     # Metodi OPTIONS per CORS
├── eventbridge.tf          # EventBridge rules
├── cloudwatch.tf           # CloudWatch alarms e SNS
├── outputs.tf              # Output e istruzioni post-deploy
├── terraform.tfvars.example
├── README.md
├── ARCHITECTURE.md         # Diagrammi e flussi
├── CLI_REFERENCE.md        # Comandi AWS CLI di riferimento
├── SFTP_SETUP.md           # Guida configurazione SFTP
└── lambda_functions/
    ├── utils.py            # Modulo condiviso (log, risposte API, validazione, sicurezza)
    ├── presigned_url.py
    ├── extract_zip.py
    ├── excel_to_csv.py
    ├── upload_to_rds.py
    ├── read_from_rds.py
    ├── sftp_send.py
    ├── s3_scan.py
    ├── list_files.py
    └── search_files.py
```

## Prerequisiti

1. AWS CLI configurato con credenziali valide
2. Terraform >= 1.0
3. Permessi AWS per: S3, Lambda, DynamoDB, RDS, API Gateway, EventBridge, IAM, Secrets Manager, SSM, CloudWatch, SNS
4. Chiave SFTP in formato RSA PEM (vedi [SFTP_SETUP.md](SFTP_SETUP.md))

## Setup Iniziale

Definire la region di riferimento: `eu-central-1` 
```bash
export AWS_REGION=eu-central-1
```

Verificare che non esistano vecchi elementi
```bash
aws secretsmanager delete-secret --secret-id "terraform-esempio-11-rds-credentials" --force-delete-without-recovery --region eu-central-1 2>&1
```

### 1. Crea la chiave SFTP RSA

```bash
# Genera coppia di chiavi RSA in formato PEM
cd ~/.aws
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""

# Carica la chiave privata in SSM Parameter Store
aws ssm put-parameter \
  --name "/alnao/dev/terraform/esempio-11/sftp/private-key" \
  --value file://~/.aws/sftp_key \
  --type "SecureString" \
  --region $AWS_REGION
```

> La chiave deve iniziare con `-----BEGIN RSA PRIVATE KEY-----`. Vedi [SFTP_SETUP.md](SFTP_SETUP.md) per dettagli e troubleshooting.

### 2. Crea i Lambda Layer per le dipendenze Python

Tre Lambda richiedono librerie esterne non presenti nel runtime Python di default:

```bash
# Layer per excel_to_csv (openpyxl)
mkdir -p /tmp/tes11/python && pip install openpyxl -t /tmp/tes11/python/
(cd /tmp/tes11 && zip -r /tmp/tes11/openpyxl-layer.zip python && rm -rf /tmp/tes11/python)
aws lambda publish-layer-version \
  --layer-name openpyxl \
  --zip-file fileb:///tmp/tes11/openpyxl-layer.zip \
  --compatible-runtimes python3.11 \
  --region $AWS_REGION

# Layer per upload_to_rds (pymysql)
mkdir -p /tmp/tes11/python && pip install pymysql -t /tmp/tes11/python/
(cd /tmp/tes11 && zip -r /tmp/tes11/pymysql-layer.zip python && rm -rf /tmp/tes11/python)
aws lambda publish-layer-version \
  --layer-name pymysql \
  --zip-file fileb:///tmp/tes11/pymysql-layer.zip \
  --compatible-runtimes python3.11 \
  --region $AWS_REGION

# Layer per sftp_send (paramiko)
mkdir -p /tmp/tes11/python && pip install paramiko -t /tmp/tes11/python/
(cd /tmp/tes11 && zip -r /tmp/tes11/paramiko-layer.zip python && rm -rf /tmp/tes11/python)
aws lambda publish-layer-version \
  --layer-name paramiko \
  --zip-file fileb:///tmp/tes11/paramiko-layer.zip \
  --compatible-runtimes python3.11 \
  --region $AWS_REGION
```


Annota gli ARN restituiti e inseriscili in `terraform.tfvars`:

```hcl
lambda_layer_arns_excel = ["arn:aws:lambda:eu-central-1:123456789:layer:openpyxl:x"]
lambda_layer_arns_rds   = ["arn:aws:lambda:eu-central-1:123456789:layer:pymysql:x"]
lambda_layer_arns_sftp  = ["arn:aws:lambda:eu-central-1:123456789:layer:paramiko:x"]
```


> Nota: la Lambda non può montare nuovi Layer a runtime leggendo una variabile d'ambiente. L'aggancio del Layer avviene solo in fase di deploy (`terraform apply`).

### 3. Configura le variabili

Copia e personalizza il file di esempio:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Variabili principali:

```hcl
project_name = "mio-progetto"
bucket_name  = "mio-bucket-storage"
alarm_email  = "alerts@example.com"

# Disabilita RDS se non necessario (risparmio ~$85/mese)
create_rds = false

# Abilita accesso pubblico S3 solo se necessario (es. hosting statico)
s3_public_read = false
```

### 4. Deploy

```bash
cd AWS-Esempio11-LambdaApplicationS3Utils
terraform init
terraform plan
terraform apply
```

### 5. Conferma subscription SNS

Se hai specificato `alarm_email`, controlla la tua email e conferma la subscription SNS per ricevere gli allarmi.

## API Gateway Endpoints

Dopo il deploy, ottieni l'URL base:

```bash
terraform output api_gateway_url
API_URL=$(terraform output -raw api_gateway_url)
echo $API_URL
# https://abc123.execute-api.eu-central-1.amazonaws.com/v1
```

Tutti gli endpoint supportano CORS (preflight OPTIONS gestito da API Gateway).

### POST /presigned-url

Genera un presigned URL per upload diretto su S3.

```bash
curl -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename": "myfile.txt", "expires_in": 3600}'
```

```json
{
  "presigned_url": "https://mio-bucket.s3.eu-central-1.amazonaws.com/...",
  "filename": "myfile.txt",
  "bucket": "mio-bucket",
  "expires_in": 3600
}
```

Prendere il presigned_url dalla risposta del curl
```bash
PRESIGNED_URL=$(curl -s -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename": "myfile.txt", "expires_in": 3600}' | jq -r '.presigned_url')
echo $PRESIGNED_URL
```

Usa l'URL per caricare il file:

```bash
echo "prova" > /tmp/myfile.txt
curl -f -L -X PUT "$PRESIGNED_URL" --upload-file /tmp/myfile.txt
```

### POST /extract-zip

Estrae un file ZIP già presente nel bucket S3.

```bash
mkdir -p /tmp/tes11zip && 
echo "prova1" > /tmp/tes11zip/myfile1.txt
echo "prova2" > /tmp/tes11zip/myfile2.txt
zip -r /tmp/test11.zip /tmp/tes11zip/ && 
rm -rf /tmp/tes11
aws s3 cp /tmp/test11.zip s3://alnao-dev-terraform-esempio11-storage/test-zip/test11.zip
curl -X POST $API_URL/extract-zip \
  -H "Content-Type: application/json" \
  -d '{"zip_key": "test-zip/test11.zip"}'
```

> I file estratti vengono salvati in `extracted/<nome_zip>/`. File con path traversal (`../`) vengono ignorati automaticamente (protezione Zip Slip).

### POST /excel-to-csv

Converte un file Excel in CSV. Richiede il layer `openpyxl`, bisogna aggiungerlo a mano selezionandolo.

```bash
curl -X POST $API_URL/excel-to-csv \
  -H "Content-Type: application/json" \
  -d '{"excel_key": "data.xlsx", "sheet_name": "Sheet1"}'
```

Il CSV viene salvato nella stessa posizione del file Excel con estensione `.csv`.

### POST /upload-to-rds

Carica i dati di un file CSV in una tabella Aurora MySQL. Richiede il layer `pymysql` e `create_rds = true`.

```bash
curl -X POST $API_URL/upload-to-rds \
  -H "Content-Type: application/json" \
  -d '{"csv_key": "data.csv", "table_name": "imported_data"}'
```

> Il nome tabella accetta solo caratteri alfanumerici e underscore (protezione SQL injection).

### GET /read-from-rds

Legge i dati da una tabella RDS popolata da `upload_to_rds`. Richiede il layer `pymysql` e `create_rds = true`.

```bash
# Tutti i dati della tabella (default: limit=100, order=DESC)
curl "$API_URL/read-from-rds?table_name=imported_data"

# Con paginazione e ordinamento
curl "$API_URL/read-from-rds?table_name=imported_data&limit=50&offset=0&order_by=id&order_dir=ASC"
```

Parametri query string:

| Parametro | Default | Descrizione |
|-----------|---------|-------------|
| `table_name` | *required* | Nome tabella da leggere |
| `limit` | 100 | Max righe (max 1000) |
| `offset` | 0 | Offset per paginazione |
| `order_by` | `id` | Colonna per ordinamento |
| `order_dir` | `DESC` | Direzione: `ASC` o `DESC` |

Risposta:
```json
{
  "table_name": "imported_data",
  "data": [{"id": 1, "lettera": "a", "valore": "1", "created_at": "..."}],
  "count": 4,
  "total_rows": 4,
  "has_more": false,
  "limit": 100,
  "offset": 0
}
```

> Il nome tabella e `order_by` accettano solo caratteri alfanumerici e underscore (protezione SQL injection).

### POST /sftp-send

Invia un file da S3 a un server SFTP tramite chiave RSA. Richiede il layer `paramiko`.

```bash
curl -X POST $API_URL/sftp-send \
  -H "Content-Type: application/json" \
  -d '{
    "s3_key": "file.txt",
    "sftp_host": "sftp.example.com",
    "sftp_username": "user",
    "sftp_remote_path": "/upload/file.txt",
    "sftp_host_key": "ssh-rsa AAAA..."
  }'
```

> `sftp_host_key` è opzionale ma consigliato in produzione per prevenire attacchi MITM.


## EventBridge

### Scansione S3 giornaliera

Eseguita alle 02:00 UTC ogni giorno (configurabile):

```hcl
s3_scan_schedule_expression = "cron(0 2 * * ? *)"
```

oppure modificare la regola per essere eseguita ogni ora al minuto 42:
```hcl
s3_scan_schedule_expression = "cron(42 * * * ? *)"
```

### GET /files

Elenca i file scansionati negli ultimi N giorni.

```bash
# Ultimi 1 giorno (default)
curl $API_URL/files

# Ultimi 7 giorni, max 50 risultati
curl "$API_URL/files?days=7&limit=50"
```

### GET /files/search

Cerca file per nome (o parte del nome).

```bash
curl "$API_URL/files/search?name=report&limit=20"
```

## DynamoDB Tables

### Tabella Logs

Registra tutte le operazioni eseguite dalle Lambda.

| Attributo | Tipo | Ruolo |
|-----------|------|-------|
| `id` | String | Partition Key — `<operation>-<timestamp_iso>-<uuid_8chars>` |
| `timestamp` | Number | Sort Key — Unix timestamp |
| `operation` | String | Nome operazione |
| `details` | Map | Dettagli specifici dell'operazione |
| `status` | String | `success` o `error` |

GSI `OperationIndex`: query per tipo di operazione.

```bash
aws dynamodb query \
  --table-name esempio-11-logs \
  --index-name OperationIndex \
  --key-condition-expression "operation = :op" \
  --expression-attribute-values '{":op":{"S":"presigned_url"}}'
```

### Tabella Scan

Inventario dei file presenti nel bucket S3, aggiornato dalla Lambda `s3_scan`.

| Attributo | Tipo | Ruolo |
|-----------|------|-------|
| `file_key` | String | Partition Key — path S3 del file |
| `scan_date` | String | Data scansione `YYYY-MM-DD` |
| `size` | Number | Dimensione in byte |
| `last_modified` | String | Data ultima modifica (ISO 8601) |
| `etag` | String | ETag S3 |

GSI `ScanDateIndex`: query per data di scansione (usato da `list_files`).

```bash
aws dynamodb query \
  --table-name esempio-11-scan \
  --index-name ScanDateIndex \
  --key-condition-expression "scan_date = :d" \
  --expression-attribute-values '{":d":{"S":"2025-05-20"}}'
```

## RDS Aurora MySQL

### Credenziali

Le credenziali RDS vengono generate automaticamente da Terraform (`random_password`) e passate alla Lambda `upload_to_rds` come **variabili d'ambiente** (criptate at-rest dalla KMS key di Lambda). Sono anche salvate in Secrets Manager come backup.

Questa scelta evita il costo di un VPC Interface Endpoint per Secrets Manager (~$7.20/mese) — la Lambda in VPC accede a S3 e DynamoDB tramite Gateway Endpoints gratuiti.

```bash
# Verifica credenziali da Secrets Manager (backup)
SECRET_ARN=$(terraform output -raw rds_secret_arn)
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query SecretString \
  --output text | jq .

### Connessione

```bash
ENDPOINT=$(terraform output -raw rds_cluster_endpoint)
mysql -h $ENDPOINT -u admin -p esempio11db
```

### Struttura tabelle create da upload_to_rds

La Lambda crea automaticamente la tabella se non esiste, inferendo le colonne dagli header del CSV:

```sql
CREATE TABLE IF NOT EXISTS `imported_data` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `colonna1` VARCHAR(255),
    `colonna2` VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```



### Auto-processing ZIP

Ogni file caricato su S3 genera un evento `Object Created` su EventBridge, che invoca automaticamente la Lambda `extract_zip`. Solo i file `.zip` vengono processati correttamente (gli altri vengono rifiutati con errore `BadZipFile`).

## CloudWatch Alarms

Con `enable_cloudwatch_alarms = true` vengono creati i seguenti allarmi:

| Allarme | Metrica | Soglia |
|---------|---------|--------|
| Lambda errors (presigned_url, extract_zip, upload_to_rds, s3_scan) | `Errors` | > 5 in 5 min |
| API Gateway 4XX | `4XXError` | > 10 in 5 min |
| API Gateway 5XX | `5XXError` | > 5 in 5 min |
| API Gateway latency | `Latency` | > 5000ms (media, 2 periodi) |

Le notifiche vengono inviate via SNS all'email configurata in `alarm_email`.

## Sicurezza

### S3 Bucket

Per default il bucket ha "Block all public access" **abilitato**. Per abilitare la lettura pubblica (es. hosting statico):

```hcl
s3_public_read = true
```

> In produzione con dati sensibili, mantenere `s3_public_read = false` e usare presigned URL o CloudFront con OAI.

### API Gateway

Gli endpoint non richiedono autenticazione (`authorization = "NONE"`). Per ambienti di produzione considerare:
- **API Key** con Usage Plan per rate limiting
- **Cognito User Pool Authorizer** per autenticazione utenti
- **Lambda Authorizer** per logica custom

### IAM (Least Privilege)

La Lambda Execution Role ha policy separate per ogni servizio:
- S3: `GetObject`, `PutObject`, `DeleteObject`, `ListBucket` — solo sul bucket del progetto
- DynamoDB: `PutItem`, `GetItem`, `UpdateItem`, `Query`, `Scan` — solo sulle tabelle del progetto
- Secrets Manager: `GetSecretValue` — solo sul secret RDS (backup)
- SSM: `GetParameter` — solo sul parametro SFTP

### VPC Endpoints

La Lambda `upload_to_rds` è in VPC per raggiungere RDS. Per permetterle di accedere agli altri servizi AWS senza NAT Gateway ($), sono configurati VPC Gateway Endpoints gratuiti:

| Endpoint | Tipo | Costo | Servizio |
|----------|------|-------|----------|
| S3 | Gateway | Gratuito | Download CSV da S3 |
| DynamoDB | Gateway | Gratuito | Logging operazioni |

### Protezioni nel codice Lambda

- **Path Traversal (S3)**: `presigned_url` valida il filename con `validate_s3_key()` rifiutando path assoluti, `../`, null bytes e nomi troppo lunghi
- **Zip Slip**: `extract_zip` valida ogni path prima dell'estrazione con `safe_zip_extract_path()`
- **SQL Injection**: `upload_to_rds` valida nomi tabella e colonne con regex whitelist
- **SFTP MITM**: `sftp_send` usa `paramiko.SSHClient` con `set_missing_host_key_policy()` — `RejectPolicy` quando `sftp_host_key` è fornita, `WarningPolicy` altrimenti
- **Credenziali**: mai hardcoded — env vars Lambda (criptate at-rest) per RDS, SSM Parameter Store per SFTP

### Modulo condiviso `utils.py`

Tutte le Lambda condividono il modulo `utils.py` che centralizza:

| Funzione | Descrizione |
|----------|-------------|
| `log_operation()` | Registra operazioni su DynamoDB con ID univoco (UUID) |
| `api_response()` | Costruisce risposte HTTP standard con CORS e serializzazione Decimal |
| `validate_s3_key()` | Valida nomi file S3 contro path traversal |
| `validate_table_name()` | Valida nomi tabella SQL (whitelist alfanumerica) |
| `validate_column_name()` | Valida nomi colonna SQL |
| `safe_zip_extract_path()` | Protezione Zip Slip per estrazione archivi |
| `decimal_default()` | Serializzatore JSON per oggetti Decimal (DynamoDB) |

### RDS

- Password generata automaticamente da `random_password`
- Credenziali passate come variabili d'ambiente Lambda (criptate at-rest dalla KMS key di Lambda)
- Credenziali anche in Secrets Manager come backup
- Security Group: accesso MySQL (3306) solo dal Security Group Lambda
- VPC Gateway Endpoints per S3 e DynamoDB (gratuiti) — no NAT Gateway
- Storage encrypted at rest

## Costi Stimati (eu-central-1)

| Servizio | Costo mensile (uso moderato) |
|----------|------------------------------|
| Lambda (1M richieste) | ~$5 |
| API Gateway (1M richieste) | ~$3.50 |
| DynamoDB (PAY_PER_REQUEST) | ~$2.50 |
| S3 (100 GB + 1M richieste) | ~$5 |
| RDS Aurora db.t3.medium | ~$85 |
| Secrets Manager | ~$0.40 |
| CloudWatch Logs (5 GB) | ~$1 |
| **Totale** | **~$100/mese** |

Per ridurre i costi: `create_rds = false` elimina la voce più costosa (-$85/mese).

## Troubleshooting

### Lambda timeout su Excel o RDS

Aumenta timeout e memoria:

```hcl
lambda_timeout     = 600
lambda_memory_size = 1024
```

### openpyxl / pymysql / paramiko non trovato

La Lambda restituisce un errore 500 con il messaggio `"library not found"`. Creare e configurare il Lambda Layer corrispondente (vedi sezione Setup).

### SFTP: Authentication failed

1. Verifica che la chiave sia in formato `-----BEGIN RSA PRIVATE KEY-----`
2. Controlla che la chiave pubblica sia in `~/.ssh/authorized_keys` sul server
3. Testa la connessione locale: `ssh -i sftp_key user@host`
4. Verifica il parametro SSM: `aws ssm get-parameter --name "/esempio-11/sftp/private-key" --with-decryption`

### RDS: Connection timeout

La Lambda `upload_to_rds` è in VPC per raggiungere RDS Aurora. Se va in timeout, verificare:
- `create_rds = true` in `terraform.tfvars`
- VPC Gateway Endpoints per S3 e DynamoDB creati correttamente
- Security Group Lambda → RDS sulla porta 3306
- Subnet configuration nel VPC di default

### DynamoDB: query list_files restituisce 0 risultati

La Lambda `s3_scan` deve essere eseguita almeno una volta per popolare la tabella. Eseguirla manualmente:

```bash
aws lambda invoke --function-name esempio-11-s3-scan --payload '{}' response.json
```

### Bucket S3 non distrutto con terraform destroy

Con `force_destroy_bucket = true` (default) Terraform svuota e distrugge il bucket automaticamente. Se impostato a `false`, svuotare manualmente prima:

```bash
aws s3 rm s3://alnao-dev-terraform-esempio11-storage --recursive
```

# Pulizia finale

```bash
# Pulizia del bucket
aws s3 rm s3://alnao-dev-terraform-esempio11-storage --recursive

# Distruggi l'infrastruttura
terraform destroy
# a volte va in erorre perchè le network interfaces non si cancellano perchè rimane bloccato per lambda-NI-securityGroups
  # In quel caso basta andare sulla console AWS e cancellarle manualmente

# Rimuovi il parametro SSM (non gestito da Terraform)
aws ssm delete-parameter --name "/alnao/dev/terraform/esempio-11/sftp/private-key"

```

# Risorse Utili

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/)
- [API Gateway REST API](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [EventBridge Patterns](https://docs.aws.amazon.com/eventbridge/latest/userguide/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/)
- [paramiko Documentation](https://www.paramiko.org/)




# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella massima misura possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


Alcuni contenuti e porzioni di codice presenti in questo repository sono stati realizzati anche grazie al supporto di strumenti di intelligenza artificiale, il cui contributo ha permesso di arricchire e velocizzare la produzione del materiale. Ogni informazione e frammento di codice è stato comunque attentamente verificato e validato, con l'obiettivo di garantire la massima qualità e affidabilità dei contenuti offerti. 


Per ulteriori dettagli, approfondimenti o richieste di chiarimento, si invita a consultare il sito [AlNao.it](https://www.alnao.it/).


## License
Made with ❤️ by <a href="https://www.alnao.it">AlNao</a>
&bull; 
Public projects 
<a href="https://www.gnu.org/licenses/gpl-3.0"  valign="middle"> <img src="https://img.shields.io/badge/License-GPL%20v3-blue?style=plastic" alt="GPL v3" valign="middle" /></a>
*Free Software!*


Il software è distribuito secondo i termini della GNU General Public License v3.0. L'uso, la modifica e la ridistribuzione sono consentiti, a condizione che ogni copia o lavoro derivato sia rilasciato con la stessa licenza. Il contenuto è fornito "così com'è", senza alcuna garanzia, esplicita o implicita.


The software is distributed under the terms of the GNU General Public License v3.0. Use, modification, and redistribution are permitted, provided that any copy or derivative work is released under the same license. The content is provided "as is", without any warranty, express or implied.
