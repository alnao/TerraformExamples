# Architettura AWS Esempio 11 - Lambda Application S3 Utils

## Diagramma Architettura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud Infrastructure                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      API Gateway REST API                        │  │
│  │  /presigned-url  /extract-zip  /excel-to-csv  /upload-to-rds   │  │
│  │  /sftp-send  /files  /files/search                              │  │
│  └────────────────────┬─────────────────────────────────────────────┘  │
│                       │                                                 │
│                       ▼                                                 │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                    Lambda Functions (8)                        │   │
│  ├────────────────────────────────────────────────────────────────┤   │
│  │  1. presigned_url    - Generate upload URLs                    │   │
│  │  2. extract_zip      - Extract ZIP files                       │   │
│  │  3. excel_to_csv     - Convert Excel to CSV                    │   │
│  │  4. upload_to_rds    - Load CSV to database                    │   │
│  │  5. sftp_send        - Send files via SFTP                     │   │
│  │  6. s3_scan          - Scan S3 bucket                          │   │
│  │  7. list_files       - List new files API                      │   │
│  │  8. search_files     - Search files API                        │   │
│  └────┬────────┬────────┬─────────┬──────────┬────────────────────┘   │
│       │        │        │         │          │                         │
│       ▼        ▼        ▼         ▼          ▼                         │
│  ┌─────────┐ ┌──────┐ ┌──────┐ ┌──────┐  ┌──────────────┐            │
│  │   S3    │ │ DDB  │ │ DDB  │ │ RDS  │  │   Systems    │            │
│  │ Bucket  │ │ Logs │ │ Scan │ │Aurora│  │   Manager    │            │
│  │         │ │Table │ │Table │ │MySQL │  │Parameter Store│           │
│  │ Storage │ │      │ │      │ │      │  │(SFTP Key)    │            │
│  └────┬────┘ └──────┘ └──────┘ └──────┘  └──────────────┘            │
│       │                    ▲                                            │
│       │                    │                                            │
│       ▼                    │                                            │
│  ┌─────────────────────────┴─────────────────────────────────────┐    │
│  │                    EventBridge                                 │    │
│  ├────────────────────────────────────────────────────────────────┤    │
│  │  • S3 Object Created → extract_zip Lambda                      │    │
│  │  • Scheduled (cron) → s3_scan Lambda (daily 02:00)            │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    Secrets Manager                             │    │
│  │  RDS Credentials (auto-generated password)                     │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    CloudWatch                                  │    │
│  ├────────────────────────────────────────────────────────────────┤    │
│  │  • Log Groups (8 Lambda + 1 API Gateway)                       │    │
│  │  • Alarms (Lambda errors, API 4xx/5xx, latency)              │    │
│  │  • Metrics & Dashboards                                        │    │
│  └────────────────────────┬───────────────────────────────────────┘    │
│                           │                                             │
│                           ▼                                             │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    SNS Topic                                   │    │
│  │  Email notifications for alarms                                │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    IAM Roles & Policies                        │    │
│  │  • Lambda Execution Role                                       │    │
│  │  • S3 Access Policy                                            │    │
│  │  • DynamoDB Access Policy                                      │    │
│  │  • Secrets Manager Policy                                      │    │
│  │  • SSM Parameter Store Policy                                  │    │
│  │  • VPC Access Policy (for RDS)                                 │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

                            External Systems
                                   │
                                   ▼
                         ┌──────────────────┐
                         │   SFTP Server    │
                         │  (via Lambda)    │
                         └──────────────────┘
```

## Flussi Principali

### 1. Upload File via Presigned URL

```
User → API Gateway → Lambda presigned_url
                  ↓
              Generate URL
                  ↓
              Return URL → User
                              ↓
                         PUT to S3
```

### 2. Auto-processing ZIP

```
File.zip uploaded to S3
        ↓
   EventBridge detects "Object Created"
        ↓
   Trigger Lambda extract_zip
        ↓
   Download ZIP from S3
        ↓
   Extract files
        ↓
   Upload extracted files to S3
        ↓
   Log operation to DynamoDB Logs
```

### 3. Excel to CSV to RDS

```
User → API Gateway → Lambda excel_to_csv
                  ↓
          Download Excel from S3
                  ↓
          Convert to CSV (openpyxl)
                  ↓
          Upload CSV to S3
                  ↓
          Log to DynamoDB
                  ↓
User → API Gateway → Lambda upload_to_rds
                  ↓
          Download CSV from S3
                  ↓
          Get RDS credentials (Secrets Manager)
                  ↓
          Connect to Aurora MySQL
                  ↓
          Create table if not exists
                  ↓
          Insert data
                  ↓
          Log to DynamoDB
```

### 4. SFTP File Transfer

```
User → API Gateway → Lambda sftp_send
                  ↓
          Download file from S3
                  ↓
          Get SFTP private key (SSM)
                  ↓
          Connect to SFTP server (paramiko)
                  ↓
          Upload file via SFTP
                  ↓
          Log to DynamoDB
```

### 5. Scheduled S3 Scan

```
EventBridge (cron: daily 02:00 UTC)
        ↓
   Trigger Lambda s3_scan
        ↓
   List all S3 objects (paginated)
        ↓
   For each file:
     - file_key
     - size
     - last_modified
     - etag
        ↓
   Save to DynamoDB Scan table
        ↓
   Log to DynamoDB Logs
```

### 6. List & Search Files

```
User → API Gateway → Lambda list_files
                  ↓
          Query DynamoDB Scan table
          (ScanDateIndex: files from last N days)
                  ↓
          Return file list
                  
User → API Gateway → Lambda search_files
                  ↓
          Scan DynamoDB Scan table
          (filter by filename pattern)
                  ↓
          Return matching files
```

## Componenti Dettagliati

### S3 Bucket
- **Public Access**: Disabilitato "Block all public access"
- **Policy**: Public read, write via presigned URL
- **Versioning**: Abilitato
- **EventBridge**: Abilitato per trigger automatici
- **Encryption**: Server-side encryption

### DynamoDB Tables

#### Logs Table
- **Purpose**: Registro operazioni
- **Keys**: 
  - PK: `id` (String) - Unique operation ID
  - SK: `timestamp` (Number) - Unix timestamp
- **GSI**: `OperationIndex` (operation, timestamp)
- **Attributes**: operation, details, status

#### Scan Table
- **Purpose**: Inventario file S3
- **Keys**: 
  - PK: `file_key` (String) - S3 object key
- **GSI**: `ScanDateIndex` (scan_date)
- **Attributes**: size, last_modified, etag

### RDS Aurora MySQL
- **Engine**: aurora-mysql 8.0
- **Instance**: db.t3.small
- **VPC**: Default VPC
- **Security**: Security Group con accesso solo da Lambda
- **Credentials**: Secrets Manager (auto-generated password)
- **Backup**: 7 days retention

### Lambda Functions
- **Runtime**: Python 3.11
- **Timeout**: 300s (configurable)
- **Memory**: 512 MB (configurable)
- **VPC**: Solo upload_to_rds (per accesso RDS)
- **Layers**: openpyxl, pymysql, paramiko (da installare)

### API Gateway
- **Type**: REST API
- **Endpoints**: 7 endpoints
- **Stage**: v1 (configurable)
- **Logging**: CloudWatch Logs con access logs
- **Authorization**: NONE (considerare API Keys o Cognito)

### EventBridge
- **Rules**: 
  1. S3 Object Created → extract_zip
  2. Scheduled scan → s3_scan (cron: 0 2 * * ? *)

### CloudWatch
- **Log Groups**: 9 (8 Lambda + 1 API Gateway)
- **Retention**: 7 giorni (configurable)
- **Alarms**: Lambda errors, API 4xx/5xx, latency
- **Metrics**: Custom metrics disponibili

### Secrets Manager
- **Secret**: RDS credentials
- **Content**: username, password, host, port, database
- **Rotation**: Non configurata (estendibile)

### SSM Parameter Store
- **Parameter**: SFTP private key RSA
- **Type**: SecureString (KMS encrypted)
- **Access**: Solo Lambda sftp_send

## Sicurezza

### Network
- RDS in VPC privata
- Lambda in VPC solo per RDS access
- Security Groups con least privilege

### IAM
- Lambda Execution Role con policy granulari
- Accesso S3 limitato al bucket specifico
- Accesso DynamoDB limitato alle tabelle specifiche
- Secrets Manager: GetSecretValue only
- SSM: GetParameter only

### Encryption
- S3: Server-side encryption
- DynamoDB: Encryption at rest
- RDS: Storage encrypted
- SSM: SecureString (KMS)
- Secrets Manager: KMS encrypted

### Credentials
- RDS: Auto-generated, stored in Secrets Manager
- SFTP: Private key in SSM, never hardcoded
- No hardcoded secrets nel codice

## Monitoring & Alerting

### CloudWatch Alarms
1. Lambda Errors (threshold: 5)
2. API Gateway 4XX (threshold: 10)
3. API Gateway 5XX (threshold: 5)
4. API Gateway Latency (threshold: 5000ms)

### Notifications
- SNS Topic con email subscription
- Alert su errori critici

### Logging
- Structured logging in JSON
- Operation tracking in DynamoDB
- CloudWatch Logs con retention

## Cost Optimization

### Free Tier
- Lambda: 1M requests/month
- API Gateway: 1M requests (12 mesi)
- DynamoDB: 25GB storage, 25 RCU/WCU
- S3: 5GB storage (12 mesi)
- CloudWatch Logs: 5GB (retention)

### Pay-per-use
- Lambda: $0.20 per 1M requests
- API Gateway: $3.50 per 1M requests
- DynamoDB: PAY_PER_REQUEST mode
- S3: Storage + requests

### Fixed Cost
- RDS Aurora t3.small: ~$35/month
- Secrets Manager: $0.40/secret/month

### Ottimizzazioni
- Disabilita RDS se non necessario
- Limita log retention (3-7 giorni)
- Usa PAY_PER_REQUEST per DynamoDB
- Cleanup S3 con lifecycle policies

## Scalabilità

### Auto-scaling
- Lambda: Auto-scaling nativo (1000 concurrent)
- API Gateway: Illimitato
- DynamoDB: PAY_PER_REQUEST (auto-scaling)
- RDS: Manuale (aggiungere read replicas)

### Limiti
- Lambda timeout: 300s (15 min max)
- API Gateway timeout: 30s
- Lambda payload: 6MB sync, 256KB async
- DynamoDB item size: 400KB

### Ottimizzazioni
- Aumentare Lambda memory per performance
- Usare S3 presigned URLs per file grandi
- Batch processing per DynamoDB
- Connection pooling per RDS

## Disaster Recovery

### Backup
- S3: Versioning enabled
- DynamoDB: Point-in-time recovery
- RDS: Automated backups (7 days)
- Secrets Manager: Automatic replication

### Recovery
- Lambda: Redeploy da Terraform
- API Gateway: Redeploy da Terraform
- DynamoDB: Restore da backup
- RDS: Restore da snapshot
- S3: Versioning recovery

## Estensioni Possibili

1. **Authentication**: Aggiungi Cognito o API Keys
2. **Rate Limiting**: Usage Plans in API Gateway
3. **File Validation**: Lambda per validazione pre-upload
4. **Notification**: SNS per notifiche operazioni
5. **Workflow**: Step Functions per orchestrazione complessa
6. **Caching**: CloudFront davanti a API Gateway
7. **Search**: ElasticSearch per ricerca avanzata file
8. **Analytics**: Athena per query S3 logs
9. **Data Lake**: Glue + Athena per analytics
10. **CI/CD**: CodePipeline per deploy automatico
