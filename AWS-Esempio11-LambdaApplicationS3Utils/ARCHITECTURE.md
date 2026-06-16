# Architettura - AWS Esempio 11 - Lambda Application S3 Utils

## Diagramma Architettura

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud Infrastructure                        │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    API Gateway REST API (v1)                      │  │
│  │  POST /presigned-url   POST /extract-zip   POST /excel-to-csv    │  │
│  │  POST /upload-to-rds   POST /sftp-send                           │  │
│  │  GET  /files           GET  /files/search                        │  │
│  │  OPTIONS * (CORS preflight — MOCK integration)                   │  │
│  └─────────────────────────┬─────────────────────────────────────────┘  │
│                            │ AWS_PROXY                                   │
│                            ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                  Lambda Functions (9) + utils.py                │    │
│  ├─────────────────────────────────────────────────────────────────┤    │
│  │  1. presigned_url   — Genera presigned URL per upload S3        │    │
│  │  2. extract_zip     — Estrae ZIP (protezione Zip Slip)          │    │
│  │  3. excel_to_csv    — Converte Excel → CSV (layer: openpyxl)    │    │
│  │  4. upload_to_rds   — Carica CSV su Aurora (layer: pymysql)     │    │
│  │  5. read_from_rds   — Legge dati da RDS (layer: pymysql)        │    │
│  │  6. sftp_send       — Invia file via SFTP (layer: paramiko)     │    │
│  │  7. s3_scan         — Scansione bucket → DynamoDB               │    │
│  │  8. list_files      — API lista file per data                   │    │
│  │  9. search_files    — API ricerca file per nome                 │    │
│  │  ─────────────────────────────────────────────────────────────  │    │
│  │  utils.py           — Modulo condiviso: log, api_response,      │    │
│  │                        validazione S3/SQL, Zip Slip               │    │
│  └──┬──────┬──────┬────┬──────────┬──────────────────────────────┘    │
│     │      │      │    │          │                                      │
│     ▼      ▼      ▼    ▼          ▼                                      │
│  ┌──────┐ ┌────┐ ┌────┐ ┌──────┐ ┌──────────────┐                      │
│  │  S3  │ │DDB │ │DDB │ │ RDS  │ │     SSM      │                      │
│  │Bucket│ │Logs│ │Scan│ │Aurora│ │Parameter     │                      │
│  │      │ │    │ │    │ │MySQL │ │Store         │                      │
│  │      │ │    │ │    │ │(VPC) │ │(SFTP Key)    │                      │
│  └──┬───┘ └────┘ └────┘ └──────┘ └──────────────┘                      │
│     │                                                                    │
│     │ EventBridge notification                                           │
│     ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                        EventBridge                               │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │  Rule 1: S3 Object Created → Lambda extract_zip                  │   │
│  │  Rule 2: cron(0 2 * * ? *) → Lambda s3_scan (giornaliera)       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Secrets Manager (backup)                    │   │
│  │  RDS credentials salvate come backup, ma la Lambda legge        │   │
│  │  le credenziali da variabili d'ambiente (criptate at-rest)      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    VPC Gateway Endpoints                        │   │
│  │  S3 Gateway Endpoint (gratuito) — accesso S3 dalla Lambda VPC   │   │
│  │  DynamoDB Gateway Endpoint (gratuito) — logging dalla Lambda VPC│   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                       CloudWatch                                 │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │  Log Groups: 8 Lambda + 1 API Gateway (retention configurabile)  │   │
│  │  Alarms: Lambda errors, API 4xx/5xx, latency → SNS → Email       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    IAM Roles & Policies                          │   │
│  │  Lambda Execution Role con policy granulari (least privilege):   │   │
│  │  S3 · DynamoDB · Secrets Manager · SSM · VPC (solo upload_rds)  │   │
│  │  Credenziali RDS: env vars Lambda (no Secrets Manager a runtime) │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

                              Sistema Esterno
                                    │
                                    ▼
                          ┌──────────────────┐
                          │   Server SFTP    │
                          │  (via paramiko)  │
                          └──────────────────┘
```

## Flussi Principali

### 1. Upload File via Presigned URL

```
Client
  │
  ├─ POST /presigned-url {"filename": "file.txt"}
  │         │
  │    Lambda presigned_url
  │         ├─ Valida input (filename, expires_in)
  │         ├─ s3.generate_presigned_url('put_object')
  │         ├─ log_operation(LOGS_TABLE, 'presigned_url', ...)
  │         └─ Return {"presigned_url": "https://..."}
  │
  └─ PUT <presigned_url> (upload diretto a S3, bypass Lambda)
```

### 2. Auto-processing ZIP (EventBridge)

```
File .zip caricato su S3
  │
  ├─ S3 emette evento "Object Created" su EventBridge
  │
  └─ EventBridge Rule: s3_object_created
       │
       └─ Lambda extract_zip
            ├─ Verifica dimensione ZIP (max 100 MB)
            ├─ Scarica ZIP da S3
            ├─ Per ogni file nell'archivio:
            │    ├─ Protezione Zip Slip (valida path con utils.safe_zip_extract_path)
            │    └─ Upload file estratto in extracted/<nome_zip>/
            ├─ log_operation(LOGS_TABLE, 'extract_zip', {..., skipped_files})
            └─ Return {extracted_files, count, skipped_files}
```

### 3. Excel → CSV → RDS

```
Client
  │
  ├─ POST /excel-to-csv {"excel_key": "data.xlsx"}
  │         │
  │    Lambda excel_to_csv (layer: openpyxl)
  │         ├─ Valida estensione (.xlsx / .xls)
  │         ├─ Scarica Excel da S3
  │         ├─ Apre workbook con openpyxl (read_only, data_only)
  │         ├─ Converte sheet selezionato in CSV
  │         ├─ Upload CSV su S3 (stessa path, estensione .csv)
  │         ├─ log_operation(...)
  │         └─ Return {"csv_key": "data.csv"}
  │
  └─ POST /upload-to-rds {"csv_key": "data.csv", "table_name": "my_table"}
            │
        Lambda upload_to_rds (layer: pymysql, in VPC)
             ├─ Valida table_name con regex whitelist (utils.validate_table_name)
             ├─ Legge credenziali DB da variabili d'ambiente (criptate at-rest)
             ├─ Scarica CSV da S3 (via VPC Gateway Endpoint)
             ├─ Valida ogni header CSV (utils.validate_column_name)
             ├─ Connessione Aurora MySQL (via Security Group)
             ├─ CREATE TABLE IF NOT EXISTS (nomi già validati)
             ├─ INSERT batch (100 righe per volta, executemany)
             ├─ COMMIT / ROLLBACK su errore
             ├─ log_operation(...) (via VPC Gateway Endpoint DynamoDB)
             └─ Return {rows_inserted}
```

### 4. Lettura dati da RDS

```
GET /read-from-rds?table_name=imported_data&limit=50&offset=0
  │
  └─ Lambda read_from_rds (layer: pymysql, in VPC)
       ├─ Valida table_name con regex whitelist (utils.validate_table_name)
       ├─ Valida order_by con regex whitelist
       ├─ Legge credenziali DB da variabili d'ambiente (criptate at-rest)
       ├─ Connessione Aurora MySQL (via Security Group)
       ├─ Verifica esistenza tabella in information_schema
       ├─ COUNT(*) per total_rows
       ├─ SELECT * con ORDER BY, LIMIT, OFFSET
       ├─ log_operation(...) (via VPC Gateway Endpoint DynamoDB)
       └─ Return {data, count, total_rows, has_more}
```

### 5. Invio File via SFTP

```
Client
  │
  └─ POST /sftp-send {"s3_key": "...", "sftp_host": "...", "sftp_host_key": "..."}
            │
        Lambda sftp_send (layer: paramiko)
             ├─ Scarica file da S3
             ├─ Recupera chiave privata RSA da SSM (cache warm)
             ├─ Carica chiave con paramiko.RSAKey.from_private_key()
             ├─ Crea SSHClient con host key policy:
             │    ├─ Se sftp_host_key fornita: RejectPolicy (verifica rigorosa)
             │    └─ Altrimenti: WarningPolicy + log warning MITM
             ├─ ssh_client.connect(hostname, port, username, pkey)
             ├─ sftp = ssh_client.open_sftp()
             ├─ sftp.putfo(file_content, remote_path)
             ├─ ssh_client.close() in finally
             ├─ log_operation(...)
             └─ Return {file_size, sftp_remote_path, host_key_verified}
```

### 5. Scansione S3 Giornaliera

```
EventBridge cron(0 2 * * ? *)
  │
   └─ Lambda s3_scan
        ├─ s3.get_paginator('list_objects_v2') — paginazione completa
        ├─ Per ogni oggetto: {file_key, scan_date, size, last_modified, etag}
        ├─ table.batch_writer() — gestisce batching e retry automaticamente
        ├─ log_operation(LOGS_TABLE, 's3_scan', {files_processed, total_size})
        └─ Return {files_processed, total_size}
```

### 6. List & Search Files

```
GET /files?days=7&limit=100
  │
  └─ Lambda list_files
       ├─ Per ogni giorno in [oggi, oggi-1, ..., oggi-N]:
       │    └─ DynamoDB.query(ScanDateIndex, scan_date = <data>)
       │       (hash key → solo operatore '=', non range)
       ├─ Accumula risultati fino al limite
       ├─ log_operation(...)
       └─ Return {files, count, days_queried}

GET /files/search?name=report&limit=50
  │
  └─ Lambda search_files
       ├─ DynamoDB.scan con FilterExpression: file_key contains <name>
       ├─ Paginazione corretta: raccoglie pagine finché count < limit
       │  (Limit=100 per pagina, non per risultato filtrato)
       ├─ log_operation(...)
       └─ Return {files, count, search_name}
```

## Componenti Dettagliati

### S3 Bucket

| Proprietà | Valore |
|-----------|--------|
| Public access | Disabilitato per default (`s3_public_read = false`) |
| Versioning | Abilitato |
| EventBridge | Abilitato (notifiche Object Created) |
| Encryption | Server-side (SSE-S3) |
| Force destroy | Configurabile (`force_destroy_bucket`) |

### DynamoDB

#### Tabella Logs

| Chiave | Tipo | Ruolo |
|--------|------|-------|
| `id` | String | Partition Key |
| `timestamp` | Number | Sort Key |
| `operation` | String | GSI `OperationIndex` (PK) |

Funzionalità: PITR abilitato, encryption at rest.

#### Tabella Scan

| Chiave | Tipo | Ruolo |
|--------|------|-------|
| `file_key` | String | Partition Key |
| `scan_date` | String | GSI `ScanDateIndex` (PK) — formato `YYYY-MM-DD` |

Funzionalità: PITR abilitato, encryption at rest.

> **Nota design**: `scan_date` è hash key del GSI, non range key. Le query usano `=` per data esatta. La Lambda `list_files` esegue una query per ogni giorno richiesto.

### Lambda Functions

| Proprietà | Valore |
|-----------|--------|
| Runtime | Python 3.11 |
| Timeout default | 300s (configurabile) |
| Memory default | 512 MB (configurabile) |
| Archivio | ZIP con file principale + `utils.py` |
| VPC | Solo `upload_to_rds` (per accesso RDS) |

Layer richiesti (ARN configurabili via variabili):

| Lambda | Variabile | Libreria |
|--------|-----------|---------|
| `excel_to_csv` | `lambda_layer_arns_excel` | openpyxl |
| `upload_to_rds` | `lambda_layer_arns_rds` | pymysql |
| `read_from_rds` | `lambda_layer_arns_rds` | pymysql |
| `sftp_send` | `lambda_layer_arns_sftp` | paramiko |

### API Gateway

| Proprietà | Valore |
|-----------|--------|
| Tipo | REST API (REGIONAL) |
| Stage | `v1` (configurabile) |
| Integrazione | AWS_PROXY (Lambda) |
| CORS | Metodi OPTIONS con MOCK integration su ogni resource |
| Logging | CloudWatch access logs in formato JSON |
| Autenticazione | NONE (estendibile con Cognito o API Key) |

### EventBridge

| Rule | Trigger | Target |
|------|---------|--------|
| `s3-scan-schedule` | `cron(0 2 * * ? *)` | Lambda `s3_scan` |
| `s3-object-created` | S3 Object Created | Lambda `extract_zip` |

La rule `s3-scan-schedule` usa `state = "ENABLED"/"DISABLED"` (parametro `is_enabled` deprecato dal provider AWS 5.x).

### RDS Aurora MySQL

| Proprietà | Valore |
|-----------|--------|
| Engine | aurora-mysql 8.0 |
| Instance | db.t3.medium (configurabile) |
| VPC | Default VPC |
| Security Group | Accesso MySQL (3306) solo da Lambda SG |
| Backup | 7 giorni retention |
| Encryption | Storage encrypted |
| Final snapshot | Configurabile (`rds_skip_final_snapshot`) |

### Secrets Manager (backup)

Contiene le credenziali RDS in formato JSON come backup. La Lambda `upload_to_rds` legge le credenziali da **variabili d'ambiente** per evitare il costo di un VPC Interface Endpoint:

```json
{
  "username": "admin",
  "password": "<generata da random_password>",
  "engine": "aurora-mysql",
  "host": "<cluster_endpoint>",
  "port": 3306,
  "database": "esempio11db"
}
```

### SSM Parameter Store

| Parametro | Tipo | Contenuto |
|-----------|------|-----------|
| `/esempio-11/sftp/private-key` | SecureString (KMS) | Chiave privata RSA PEM |

### CloudWatch

| Risorsa | Dettaglio |
|---------|-----------|
| Log Groups | 9 totali (8 Lambda + 1 API Gateway) |
| Retention | Configurabile (`log_retention_days`, default 7) |
| Alarms | 7 totali (4 Lambda errors + 3 API Gateway) |
| Notifiche | SNS → Email (se `alarm_email` configurata) |

## Sicurezza

### Protezioni implementate nel codice

| Vulnerabilità | Lambda | Protezione |
|---------------|--------|-----------|
| Zip Slip | `extract_zip` | `utils.safe_zip_extract_path()` — verifica che il path estratto rimanga dentro la directory base |
| SQL Injection | `upload_to_rds` | `utils.validate_table_name()` e `validate_column_name()` — regex whitelist `^[a-zA-Z_][a-zA-Z0-9_]{0,63}$` |
| SFTP MITM | `sftp_send` | `paramiko.SSHClient` con `set_missing_host_key_policy()`: `RejectPolicy` se `sftp_host_key` fornita, `WarningPolicy` altrimenti |
| Credenziali esposte | tutti | Mai hardcoded; env vars Lambda (criptate at-rest) per RDS, SSM per SFTP |

### Network

- RDS in VPC, accessibile solo dalla Lambda `upload_to_rds` tramite Security Group dedicato
- Lambda in VPC solo quando necessario (evita cold start overhead inutile)
- **VPC Gateway Endpoints** (gratuiti) per S3 e DynamoDB — permettono alla Lambda in VPC di accedere a questi servizi senza NAT Gateway
- Credenziali RDS passate come env vars Lambda (criptate at-rest) — evita il costo di un Interface Endpoint per Secrets Manager (~$7.20/mese)
- Egress Lambda SG: aperto (necessario per chiamate AWS API)

### IAM

- Un singolo Lambda Execution Role con policy inline separate per servizio
- Nessuna policy `*` — ogni azione è esplicitamente elencata
- Accesso Secrets Manager condizionale: ARN placeholder quando `create_rds = false` (evita policy con `Resource = []` invalida)

## Scalabilità e Limiti

| Componente | Limite rilevante |
|------------|-----------------|
| Lambda concurrency | 1000 (default account) |
| API Gateway timeout | 29s (hard limit) |
| Lambda payload sync | 6 MB |
| DynamoDB item | 400 KB |
| ZIP processabile | 100 MB (limite configurato in `extract_zip`) |
| `list_files` giorni | max 365 (1 query DynamoDB per giorno) |
| `search_files` risultati | max 500 |

## Disaster Recovery

| Risorsa | Meccanismo |
|---------|-----------|
| S3 | Versioning abilitato |
| DynamoDB | Point-in-time recovery (PITR) abilitato |
| RDS | Automated backup 7 giorni; snapshot finale configurabile |
| Lambda | Rideploy da Terraform (codice in repository) |
| Secrets | Secrets Manager con versioning automatico |

## Estensioni Possibili

1. **Autenticazione API**: Cognito User Pool Authorizer o API Key con Usage Plan
2. **Rate limiting**: Usage Plans in API Gateway
3. **Ricerca avanzata**: OpenSearch per `search_files` (sostituisce DynamoDB Scan)
4. **Workflow complessi**: Step Functions per orchestrare Excel → CSV → RDS in sequenza
5. **CDN**: CloudFront davanti ad API Gateway per caching e protezione DDoS
6. **RDS Proxy**: Connection pooling per `upload_to_rds` con molte invocazioni concorrenti
7. **Notifiche operazioni**: SNS topic per notificare completamento elaborazioni
8. **CI/CD**: CodePipeline per deploy automatico al push su repository
9. **Analytics**: Athena + Glue per query sui file S3 senza Lambda
10. **Rotation credenziali**: Secrets Manager rotation automatica per RDS
