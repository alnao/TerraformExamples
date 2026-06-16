# CLI Reference - AWS Esempio 11

Comandi AWS CLI e curl di riferimento rapido per operare sull'infrastruttura.

## Setup e Deploy

### Prerequisiti

```bash
# Genera chiave SFTP RSA (formato PEM obbligatorio)
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""

# Carica chiave privata in SSM Parameter Store
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value file://sftp_key \
  --type "SecureString" \
  --region eu-central-1

# Crea Lambda Layer per openpyxl
mkdir -p python && pip install openpyxl -t python/
zip -r openpyxl-layer.zip python && rm -rf python
aws lambda publish-layer-version \
  --layer-name openpyxl \
  --zip-file fileb://openpyxl-layer.zip \
  --compatible-runtimes python3.11 \
  --region eu-central-1

# Crea Lambda Layer per pymysql
mkdir -p python && pip install pymysql -t python/
zip -r pymysql-layer.zip python && rm -rf python
aws lambda publish-layer-version \
  --layer-name pymysql \
  --zip-file fileb://pymysql-layer.zip \
  --compatible-runtimes python3.11 \
  --region eu-central-1

# Crea Lambda Layer per paramiko
mkdir -p python && pip install paramiko -t python/
zip -r paramiko-layer.zip python && rm -rf python
aws lambda publish-layer-version \
  --layer-name paramiko \
  --zip-file fileb://paramiko-layer.zip \
  --compatible-runtimes python3.11 \
  --region eu-central-1
```

### Deploy Terraform

```bash
terraform init
terraform plan
terraform apply

# Esporta variabili di ambiente per i comandi successivi
export API_URL=$(terraform output -raw api_gateway_url)
export BUCKET_NAME=$(terraform output -raw s3_bucket_name)
export RDS_ENDPOINT=$(terraform output -raw rds_cluster_endpoint)
export SECRET_ARN=$(terraform output -raw rds_secret_arn)

echo "API_URL: $API_URL"
```

---

## API Gateway — Chiamate curl

### POST /presigned-url

Genera un presigned URL per upload diretto su S3 (bypass Lambda).

```bash
# Genera URL (default: scade in 3600s)
curl -s -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename": "uploads/test.txt", "expires_in": 3600}' | jq .

# Carica il file usando il presigned URL
PRESIGNED=$(curl -s -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename": "uploads/test.txt"}' | jq -r .presigned_url)

curl -X PUT "$PRESIGNED" --upload-file test.txt
```

### POST /extract-zip

Estrae un file ZIP già presente nel bucket.

```bash
curl -s -X POST $API_URL/extract-zip \
  -H "Content-Type: application/json" \
  -d '{"zip_key": "uploads/archive.zip"}' | jq .

# Risposta attesa:
# {
#   "message": "ZIP extracted successfully",
#   "extracted_files": ["extracted/archive/file1.txt", ...],
#   "count": 3,
#   "skipped_files": []
# }
```

### POST /excel-to-csv

Converte un file Excel in CSV. Richiede layer `openpyxl`.

```bash
# Prima foglio (default)
curl -s -X POST $API_URL/excel-to-csv \
  -H "Content-Type: application/json" \
  -d '{"excel_key": "data/report.xlsx"}' | jq .

# Foglio specifico per nome
curl -s -X POST $API_URL/excel-to-csv \
  -H "Content-Type: application/json" \
  -d '{"excel_key": "data/report.xlsx", "sheet_name": "Vendite"}' | jq .
```

### POST /upload-to-rds

Carica dati CSV su Aurora MySQL. Richiede layer `pymysql` e `create_rds = true`.

```bash
curl -s -X POST $API_URL/upload-to-rds \
  -H "Content-Type: application/json" \
  -d '{"csv_key": "data/report.csv", "table_name": "imported_data"}' | jq .

# Nota: table_name accetta solo [a-zA-Z_][a-zA-Z0-9_]{0,63}
# Nomi con caratteri speciali vengono rifiutati con HTTP 400
```

### POST /sftp-send

Invia un file da S3 a un server SFTP. Richiede layer `paramiko`.

```bash
# Senza verifica host key (non consigliato in produzione)
curl -s -X POST $API_URL/sftp-send \
  -H "Content-Type: application/json" \
  -d '{
    "s3_key": "exports/file.csv",
    "sftp_host": "sftp.example.com",
    "sftp_username": "user",
    "sftp_remote_path": "/incoming/file.csv"
  }' | jq .

# Con verifica host key (consigliato)
HOST_KEY=$(ssh-keyscan -t rsa sftp.example.com 2>/dev/null | awk '{print $2, $3}')
curl -s -X POST $API_URL/sftp-send \
  -H "Content-Type: application/json" \
  -d "{
    \"s3_key\": \"exports/file.csv\",
    \"sftp_host\": \"sftp.example.com\",
    \"sftp_username\": \"user\",
    \"sftp_remote_path\": \"/incoming/file.csv\",
    \"sftp_host_key\": \"$HOST_KEY\"
  }" | jq .
```

### GET /files

Elenca i file scansionati negli ultimi N giorni.

```bash
# Ultimi 1 giorno (default)
curl -s $API_URL/files | jq .

# Ultimi 7 giorni, max 50 risultati
curl -s "$API_URL/files?days=7&limit=50" | jq .

# Solo conteggio
curl -s "$API_URL/files?days=30" | jq .count
```

### GET /files/search

Cerca file per nome (case-insensitive, ricerca parziale).

```bash
curl -s "$API_URL/files/search?name=report" | jq .
curl -s "$API_URL/files/search?name=.csv&limit=100" | jq '.files[].file_key'
```

---

## S3

```bash
# Upload diretto (senza presigned URL)
aws s3 cp myfile.txt s3://$BUCKET_NAME/uploads/

# Lista oggetti
aws s3 ls s3://$BUCKET_NAME/ --recursive --human-readable

# Download
aws s3 cp s3://$BUCKET_NAME/file.txt .

# Svuota bucket (necessario prima di terraform destroy se force_destroy=false)
aws s3 rm s3://$BUCKET_NAME --recursive
```

---

## DynamoDB

### Tabella Logs

```bash
# Query per tipo di operazione (usa GSI OperationIndex)
aws dynamodb query \
  --table-name esempio-11-logs \
  --index-name OperationIndex \
  --key-condition-expression "operation = :op" \
  --expression-attribute-values '{":op":{"S":"presigned_url"}}' \
  --limit 10 | jq '.Items'

# Operazioni disponibili: presigned_url, extract_zip, excel_to_csv,
#                         upload_to_rds, sftp_send, s3_scan, list_files, search_files

# Scan ultimi log (non efficiente su tabelle grandi)
aws dynamodb scan \
  --table-name esempio-11-logs \
  --limit 20 | jq '.Items'
```

### Tabella Scan

```bash
# Query file scansionati in una data specifica (usa GSI ScanDateIndex)
aws dynamodb query \
  --table-name esempio-11-scan \
  --index-name ScanDateIndex \
  --key-condition-expression "scan_date = :d" \
  --expression-attribute-values "{\":d\":{\"S\":\"$(date +%Y-%m-%d)\"}}" | jq '.Items | length'

# Recupera un file specifico per chiave
aws dynamodb get-item \
  --table-name esempio-11-scan \
  --key '{"file_key":{"S":"uploads/test.txt"}}' | jq .
```

---

## Lambda

### Invocazione diretta

```bash
# presigned_url
aws lambda invoke \
  --function-name esempio-11-presigned-url \
  --payload '{"body":"{\"filename\":\"test.txt\"}"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json | jq .

# s3_scan (trigger manuale)
aws lambda invoke \
  --function-name esempio-11-s3-scan \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json | jq .

# extract_zip (simula evento EventBridge)
aws lambda invoke \
  --function-name esempio-11-extract-zip \
  --payload '{"bucket":"'$BUCKET_NAME'","key":"uploads/archive.zip"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json | jq .
```

### Log CloudWatch

```bash
# Segui log in tempo reale
aws logs tail /aws/lambda/esempio-11-presigned-url --follow

# Ultimi 100 log
aws logs tail /aws/lambda/esempio-11-s3-scan --since 1h

# Cerca errori con CloudWatch Insights
aws logs start-query \
  --log-group-name /aws/lambda/esempio-11-presigned-url \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20'
```

---

## RDS Aurora MySQL

```bash
# Leggi credenziali da Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query SecretString \
  --output text | jq .

# Estrai password
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query SecretString \
  --output text | jq -r .password)

# Connessione MySQL
mysql -h $RDS_ENDPOINT -u admin -p$DB_PASS esempio11db

# Query rapide
mysql -h $RDS_ENDPOINT -u admin -p$DB_PASS esempio11db \
  -e "SHOW TABLES; SELECT COUNT(*) FROM imported_data;"
```

---

## EventBridge

```bash
# Lista regole del progetto
aws events list-rules --name-prefix esempio-11

# Dettaglio regola schedule
aws events describe-rule --name esempio-11-s3-scan-schedule

# Disabilita/abilita schedule
aws events disable-rule --name esempio-11-s3-scan-schedule
aws events enable-rule  --name esempio-11-s3-scan-schedule

# Modifica schedule (es. ogni ora invece che giornaliero)
aws events put-rule \
  --name esempio-11-s3-scan-schedule \
  --schedule-expression "rate(1 hour)"
```

---

## SSM Parameter Store

```bash
# Leggi chiave SFTP (con decryption)
aws ssm get-parameter \
  --name "/esempio-11/sftp/private-key" \
  --with-decryption \
  --query Parameter.Value \
  --output text

# Aggiorna chiave SFTP
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value file://new_sftp_key \
  --type "SecureString" \
  --overwrite

# Elimina parametro (prima di terraform destroy)
aws ssm delete-parameter --name "/esempio-11/sftp/private-key"
```

---

## CloudWatch Alarms

```bash
# Lista allarmi del progetto
aws cloudwatch describe-alarms \
  --alarm-name-prefix esempio-11 \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}' \
  --output table

# Metriche Lambda (ultimi 5 minuti)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=esempio-11-presigned-url \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Metriche API Gateway
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=esempio-11-api Name=Stage,Value=v1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

---

## Test Workflow Completo

```bash
#!/bin/bash
set -e

export API_URL=$(terraform output -raw api_gateway_url)
export BUCKET_NAME=$(terraform output -raw s3_bucket_name)

echo "=== Test Workflow Esempio 11 ==="

# 1. Crea un file ZIP di test
echo "file di test" > test_content.txt
zip test_archive.zip test_content.txt

# 2. Genera presigned URL e carica ZIP
echo "1. Upload ZIP via presigned URL..."
PRESIGNED=$(curl -s -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename":"uploads/test_archive.zip"}' | jq -r .presigned_url)
curl -s -X PUT "$PRESIGNED" --upload-file test_archive.zip
echo "   OK"

# 3. Estrai ZIP via API
echo "2. Estrazione ZIP..."
curl -s -X POST $API_URL/extract-zip \
  -H "Content-Type: application/json" \
  -d '{"zip_key":"uploads/test_archive.zip"}' | jq .count
echo "   OK"

# 4. Esegui scansione S3
echo "3. Scansione S3..."
aws lambda invoke \
  --function-name esempio-11-s3-scan \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/scan_response.json > /dev/null
cat /tmp/scan_response.json | jq .body | jq -r . | jq .files_processed
echo "   OK"

# 5. Lista file
echo "4. Lista file (ultimi 1 giorno)..."
curl -s "$API_URL/files?days=1" | jq .count
echo "   OK"

# 6. Cerca file
echo "5. Ricerca file 'test'..."
curl -s "$API_URL/files/search?name=test" | jq .count
echo "   OK"

# Cleanup locale
rm -f test_content.txt test_archive.zip /tmp/scan_response.json

echo "=== Test completato ==="
```

---

## Verifica Stato Risorse

```bash
# Stato generale
echo "=== S3 ===" && aws s3api head-bucket --bucket $BUCKET_NAME && echo "OK"
echo "=== DynamoDB Logs ===" && aws dynamodb describe-table --table-name esempio-11-logs --query 'Table.TableStatus'
echo "=== DynamoDB Scan ===" && aws dynamodb describe-table --table-name esempio-11-scan --query 'Table.TableStatus'
echo "=== Lambda ===" && aws lambda list-functions \
  --query 'Functions[?contains(FunctionName, `esempio-11`)].{Name:FunctionName,State:State}' \
  --output table
echo "=== API Gateway ===" && aws apigateway get-rest-apis \
  --query 'items[?name==`esempio-11-api`].{Name:name,Id:id}' \
  --output table
```

---

## Pulizia

```bash
# 1. Rimuovi parametro SSM (non gestito da Terraform)
aws ssm delete-parameter --name "/esempio-11/sftp/private-key"

# 2. Se force_destroy_bucket = false, svuota il bucket manualmente
aws s3 rm s3://$BUCKET_NAME --recursive

# 3. Distruggi infrastruttura
terraform destroy
```

---

## Variabili di Ambiente Utili

```bash
# Aggiungi a ~/.bashrc o ~/.zshrc
export API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
export BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)
export RDS_ENDPOINT=$(terraform output -raw rds_cluster_endpoint 2>/dev/null)
export SECRET_ARN=$(terraform output -raw rds_secret_arn 2>/dev/null)

# Alias rapidi
alias e11-scan='aws lambda invoke --function-name esempio-11-s3-scan --payload "{}" --cli-binary-format raw-in-base64-out /tmp/e11_scan.json && cat /tmp/e11_scan.json | jq .'
alias e11-files='curl -s "$API_URL/files?days=1" | jq .'
alias e11-logs='aws logs tail /aws/lambda/esempio-11-presigned-url --follow'
alias e11-s3='aws s3 ls s3://$BUCKET_NAME/ --recursive --human-readable'
```
