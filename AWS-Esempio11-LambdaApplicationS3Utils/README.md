# AWS Esempio 11 - Lambda Application S3 Utils

Applicazione serverless completa per gestione file S3 con elaborazione automatica, integrazione RDS, SFTP e API REST.

## Caratteristiche

### Architettura Completa
- **S3 Bucket** con public access policy personalizzata
- **8 Lambda Functions** per elaborazione file
- **2 DynamoDB Tables** per log e scansione file
- **RDS Aurora MySQL** per storage dati relazionali
- **API Gateway REST** con 7 endpoint
- **EventBridge** per orchestrazione e scheduling
- **Secrets Manager** per credenziali RDS
- **SSM Parameter Store** per chiave SFTP
- **CloudWatch** con alarms e logging
- **IAM** con policy granulari

### Funzionalità Lambda

1. **Presigned URL** - Genera URL firmati per upload file
2. **Extract ZIP** - Estrazione automatica file ZIP
3. **Excel to CSV** - Conversione Excel in CSV
4. **Upload to RDS** - Caricamento dati CSV su database
5. **SFTP Send** - Invio file via SFTP con chiave RSA
6. **S3 Scan** - Scansione giornaliera file S3
7. **List Files** - API per elenco file nuovi
8. **Search Files** - API per ricerca file per nome

## Struttura

```
AWS-Esempio11-LambdaApplicationS3Utils/
├── backend.tf              # S3 backend configuration
├── variables.tf            # Variabili configurabili
├── main.tf                 # S3, DynamoDB, RDS, IAM
├── lambda.tf               # Lambda functions
├── api_gateway.tf          # API Gateway REST
├── eventbridge.tf          # EventBridge rules
├── cloudwatch.tf           # CloudWatch alarms
├── outputs.tf              # Output e istruzioni
├── README.md               # Questa documentazione
└── lambda_functions/       # Codice Lambda
    ├── presigned_url.py
    ├── extract_zip.py
    ├── excel_to_csv.py
    ├── upload_to_rds.py
    ├── sftp_send.py
    ├── s3_scan.py
    ├── list_files.py
    └── search_files.py
```

## Prerequisiti

1. AWS CLI configurato
2. Terraform >= 1.0
3. Credenziali AWS con permessi per:
   - S3, Lambda, DynamoDB, RDS
   - API Gateway, EventBridge
   - IAM, Secrets Manager, SSM
   - CloudWatch, SNS
4. Chiave SFTP in formato RSA (vedi setup)

## Setup Iniziale

### 1. Crea Chiave SFTP RSA

La Lambda per SFTP richiede una chiave privata in formato RSA salvata in SSM Parameter Store:

```bash
# Genera coppia di chiavi RSA
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""

# Questo genera due file:
# - sftp_key (chiave privata)
# - sftp_key.pub (chiave pubblica)

# Carica chiave privata in SSM Parameter Store
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value "file://sftp_key" \
  --type "SecureString" \
  --region eu-central-1
```

**IMPORTANTE**: La chiave DEVE essere in formato RSA classico (PEM). Se hai errori, rigenera con `-m PEM`.

### 2. Inizializzazione Terraform

```bash
cd AWS-Esempio11-LambdaApplicationS3Utils
terraform init
```

### 3. Personalizza Variabili (opzionale)

Crea `terraform.tfvars`:

```hcl
project_name = "my-app"
bucket_name  = "my-app-storage"
alarm_email  = "alerts@example.com"

# Disabilita RDS se non serve
create_rds = false
```

### 4. Deploy

```bash
# Piano
terraform plan

# Applica
terraform apply
```

### 5. Conferma SNS Subscription

Se hai specificato `alarm_email`, controlla la tua email e conferma la subscription SNS.

## API Gateway Endpoints

Dopo il deploy, ottieni l'URL base:

```bash
terraform output api_gateway_url
# Output: https://abc123.execute-api.eu-central-1.amazonaws.com/v1
```

### 1. Generate Presigned URL (POST)

```bash
curl -X POST https://YOUR_API_URL/v1/presigned-url \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "myfile.txt",
    "expires_in": 3600
  }'
```

Response:
```json
{
  "presigned_url": "https://...",
  "filename": "myfile.txt",
  "bucket": "...",
  "expires_in": 3600
}
```

Usa l'URL per upload:
```bash
curl -X PUT "PRESIGNED_URL" \
  --upload-file myfile.txt
```

### 2. Extract ZIP (POST)

```bash
curl -X POST https://YOUR_API_URL/v1/extract-zip \
  -H "Content-Type: application/json" \
  -d '{
    "zip_key": "uploads/archive.zip"
  }'
```

### 3. Excel to CSV (POST)

```bash
curl -X POST https://YOUR_API_URL/v1/excel-to-csv \
  -H "Content-Type: application/json" \
  -d '{
    "excel_key": "data.xlsx",
    "sheet_name": "Sheet1"
  }'
```

### 4. Upload to RDS (POST)

```bash
curl -X POST https://YOUR_API_URL/v1/upload-to-rds \
  -H "Content-Type: application/json" \
  -d '{
    "csv_key": "data.csv",
    "table_name": "imported_data"
  }'
```

### 5. SFTP Send (POST)

```bash
curl -X POST https://YOUR_API_URL/v1/sftp-send \
  -H "Content-Type: application/json" \
  -d '{
    "s3_key": "file.txt",
    "sftp_host": "sftp.example.com",
    "sftp_username": "user",
    "sftp_remote_path": "/upload/file.txt"
  }'
```

### 6. List Files (GET)

```bash
# File degli ultimi 1 giorno (default)
curl https://YOUR_API_URL/v1/files

# File degli ultimi 7 giorni
curl "https://YOUR_API_URL/v1/files?days=7&limit=50"
```

### 7. Search Files (GET)

```bash
curl "https://YOUR_API_URL/v1/files/search?name=test&limit=20"
```

## DynamoDB Tables

### Tabella Logs (`esempio-11-logs`)

Registra tutte le operazioni:

```
Partition Key: id (String)
Sort Key: timestamp (Number)
Attributes:
- operation (String)
- details (Map)
- status (String)

GSI: OperationIndex
- operation (PK)
- timestamp (SK)
```

Query logs:
```bash
aws dynamodb query \
  --table-name esempio-11-logs \
  --index-name OperationIndex \
  --key-condition-expression "operation = :op" \
  --expression-attribute-values '{":op":{"S":"presigned_url"}}'
```

### Tabella Scan (`esempio-11-scan`)

Lista file scansionati:

```
Partition Key: file_key (String)
Attributes:
- scan_date (String)
- size (Number)
- last_modified (String)
- etag (String)

GSI: ScanDateIndex
- scan_date (PK)
```

## RDS Aurora MySQL

### Connessione

Ottieni credenziali:

```bash
# ARN del secret
terraform output rds_secret_arn

# Leggi credenziali
aws secretsmanager get-secret-value \
  --secret-id <SECRET_ARN> \
  --query SecretString \
  --output text | jq .
```

Connessione MySQL:

```bash
# Ottieni endpoint
terraform output rds_cluster_endpoint

# Connetti
mysql -h <ENDPOINT> -u admin -p esempio11db
```

### Struttura Dati

Le Lambda creano automaticamente tabelle quando caricano dati CSV. Esempio:

```sql
CREATE TABLE IF NOT EXISTS imported_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    column1 VARCHAR(255),
    column2 VARCHAR(255),
    ...
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## EventBridge

### Scansione S3 Giornaliera

Configurata per eseguire alle 02:00 UTC ogni giorno:

```hcl
schedule_expression = "cron(0 2 * * ? *)"
```

Modifica in `variables.tf` o override:

```bash
terraform apply -var="s3_scan_schedule_expression=cron(0 12 * * ? *)"
```

### Auto-processing ZIP

EventBridge trigger automatico su upload file:
- Evento: S3 Object Created
- Target: Lambda Extract ZIP
- Solo file `.zip` vengono processati

## CloudWatch Alarms

Se `enable_cloudwatch_alarms = true`:

- Lambda errors (threshold: 5 errors)
- API Gateway 4XX errors (threshold: 10)
- API Gateway 5XX errors (threshold: 5)
- API Gateway high latency (threshold: 5000ms)

Notifiche via SNS (se email configurata).

## Lambda Layers

Alcune Lambda richiedono librerie esterne:

### Excel to CSV - Layer con openpyxl

```bash
mkdir -p python
pip install openpyxl -t python/
zip -r openpyxl-layer.zip python
aws lambda publish-layer-version \
  --layer-name openpyxl \
  --zip-file fileb://openpyxl-layer.zip \
  --compatible-runtimes python3.11
```

Aggiungi layer ARN in `lambda.tf`:

```hcl
resource "aws_lambda_function" "excel_to_csv" {
  ...
  layers = ["arn:aws:lambda:REGION:ACCOUNT:layer:openpyxl:1"]
}
```

### Upload to RDS - Layer con pymysql

```bash
mkdir -p python
pip install pymysql -t python/
zip -r pymysql-layer.zip python
aws lambda publish-layer-version \
  --layer-name pymysql \
  --zip-file fileb://pymysql-layer.zip \
  --compatible-runtimes python3.11
```

### SFTP Send - Layer con paramiko

```bash
mkdir -p python
pip install paramiko -t python/
zip -r paramiko-layer.zip python
aws lambda publish-layer-version \
  --layer-name paramiko \
  --zip-file fileb://paramiko-layer.zip \
  --compatible-runtimes python3.11
```

## Tagging

Tutte le risorse sono taggate con:

```hcl
tags = {
  Environment = "dev"
  Owner       = "alnao"
  Example     = "Esempio11LambdaApplicationS3Utils"
  CreatedBy   = "Terraform"
  Project     = var.project_name
}
```

Personalizza con `additional_tags`:

```hcl
additional_tags = {
  CostCenter = "Engineering"
  Team       = "Backend"
}
```

## Sicurezza

### S3 Bucket Policy

Il bucket ha "Block all public access" **disabilitato** con policy custom che permette:
- Public read su tutti gli oggetti
- Write solo tramite presigned URL

**Produzione**: Limita public read o usa CloudFront con OAI.

### IAM Policies

Policy granulari per Lambda:
- S3: GetObject, PutObject, DeleteObject, ListBucket
- DynamoDB: PutItem, GetItem, Query, Scan
- Secrets Manager: GetSecretValue
- SSM: GetParameter

### RDS Credentials

Credenziali gestite tramite **Secrets Manager**:
- Password generata automaticamente
- Rotation configurabile (non implementata in questo esempio)

### SFTP Private Key

Chiave privata salvata in **SSM Parameter Store**:
- Type: SecureString (encrypted with KMS)
- Accesso solo per Lambda SFTP Send

## Costi Stimati (EU-Central-1)

**Mensili per uso moderato**:
- Lambda: ~$5 (1M richieste)
- API Gateway: ~$3.50 (1M richieste)
- DynamoDB: ~$2.50 (PAY_PER_REQUEST)
- S3: ~$5 (100GB storage, 1M richieste)
- RDS Aurora t3.small: ~$35
- Secrets Manager: ~$0.40
- SSM Parameter Store: Free
- CloudWatch Logs: ~$1 (5GB)

**Totale stimato**: ~$52/mese

**Risparmi**:
- Disabilita RDS se non serve (-$35)
- Usa Lambda solo quando necessario
- Limita log retention a 3-7 giorni

## Troubleshooting

### Lambda Timeout su Excel/RDS

Aumenta timeout e memoria in `variables.tf`:

```hcl
lambda_timeout     = 600
lambda_memory_size = 1024
```

### SFTP Connection Failed

Verifica:
1. Chiave in formato RSA PEM
2. Parametro SSM esiste
3. Firewall/security group destinazione
4. Username e host corretti

```bash
# Test chiave
ssh -i sftp_key user@sftp.example.com

# Verifica parametro SSM
aws ssm get-parameter \
  --name "/esempio-11/sftp/private-key" \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

### RDS Connection Timeout

Lambda deve essere in VPC per accedere RDS:
- Verifica security group
- Subnet configuration
- Lambda VPC config in `lambda.tf`

### DynamoDB ProvisionedThroughputExceededException

Passa a PAY_PER_REQUEST (default) o aumenta capacità:

```hcl
dynamodb_billing_mode = "PAY_PER_REQUEST"
```

## Best Practices

1. **Logging**: Tutti i log sono in CloudWatch con retention configurabile
2. **Monitoring**: Alarms configurati per errori critici
3. **Security**: Credenziali in Secrets Manager/SSM, mai hardcoded
4. **Tagging**: Tag consistenti per cost tracking
5. **Versioning**: S3 versioning abilitato per disaster recovery
6. **Encryption**: Encryption at rest per S3, DynamoDB, RDS
7. **IAM**: Policy minime necessarie (least privilege)

## Testing

### Test Completo Workflow

```bash
# 1. Genera presigned URL
PRESIGNED=$(curl -s -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.zip"}' | jq -r .presigned_url)

# 2. Upload file ZIP
curl -X PUT "$PRESIGNED" --upload-file test.zip

# 3. Aspetta elaborazione (EventBridge trigger automatico)
sleep 10

# 4. Lista file estratti
curl "$API_URL/files?days=1"

# 5. Cerca file specifico
curl "$API_URL/files/search?name=test"
```

### Test RDS Upload

```bash
# 1. Upload CSV
aws s3 cp data.csv s3://YOUR_BUCKET/

# 2. Carica su RDS
curl -X POST $API_URL/upload-to-rds \
  -H "Content-Type: application/json" \
  -d '{"csv_key":"data.csv","table_name":"test_table"}'

# 3. Verifica in MySQL
mysql -h $RDS_ENDPOINT -u admin -p -e "SELECT COUNT(*) FROM esempio11db.test_table"
```

## Pulizia

```bash
# Svuota bucket S3 prima di destroy
aws s3 rm s3://YOUR_BUCKET --recursive

# Destroy infrastruttura
terraform destroy
```

## Risorse Utili

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [API Gateway REST API](https://docs.aws.amazon.com/apigateway/)
- [EventBridge Patterns](https://docs.aws.amazon.com/eventbridge/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/dynamodb/)
- [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)

## Note Importanti

### Chiave SFTP RSA
La chiave privata SFTP **DEVE** essere in formato RSA classico. Se usi OpenSSH moderno che genera formato openssh, converti:

```bash
ssh-keygen -p -m PEM -f sftp_key
```

### Lambda Layers
Le Lambda per Excel, RDS e SFTP richiedono layer con librerie esterne. Vedi sezione "Lambda Layers" per istruzioni.

### RDS Opzionale
RDS può essere disabilitato con `create_rds = false`. Le Lambda continueranno a funzionare (tranne upload_to_rds).

### Public Access S3
Il bucket ha public read abilitato. Per produzione, considera CloudFront con Origin Access Identity.

## Autore

Created by: alnao  
Example: AWS-Esempio11-LambdaApplicationS3Utils  
Terraform Version: >= 1.0  
AWS Provider: ~> 5.0
