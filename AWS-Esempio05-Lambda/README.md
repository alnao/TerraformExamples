# AWS Esempio 05 - Lambda Function

Questo esempio mostra come creare una AWS Lambda function con Terraform che lista gli oggetti in un bucket S3 in base al path fornito come parametro.

## Risorse create

- **S3 Bucket**: Bucket per testing della Lambda
- **IAM Role**: Ruolo per la Lambda con permessi S3
- **IAM Policies**: Policy per accesso S3 e CloudWatch Logs
- **Lambda Function**: Function Python 3.11
- **CloudWatch Log Group**: Log group per i log della Lambda
- **Lambda Function URL**: (Opzionale) URL pubblico per invocare la Lambda
- **Lambda Alias**: (Opzionale) Alias per versioning
- **CloudWatch Alarms**: (Opzionale) Allarmi per errori e throttling
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio05Lambda/terraform.tfstate`.

## Prerequisiti

- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)

## Caratteristiche

✅ **Lambda Function** in Python 3.11  
✅ **S3 Integration** per listing oggetti  
✅ **Function URL** per invocazione HTTP diretta  
✅ **CORS configurato** per chiamate cross-origin  
✅ **IAM Role** con least privilege  
✅ **CloudWatch Logs** con retention configurabile  
✅ **Environment variables** per configurazione  
✅ **VPC support** opzionale  
✅ **Dead Letter Queue** opzionale  
✅ **Lambda Layers** support  
✅ **CloudWatch Alarms** per monitoring  

## Funzionamento della Lambda

La Lambda function:
1. Riceve un evento con parametro `path` opzionale
2. Lista gli oggetti nel bucket S3 nel path specificato
3. Ritorna un JSON con lista degli oggetti e metadata

### Input Event
```json
{
  "queryStringParameters": {
    "path": "folder/subfolder/"
  }
}
```

### Output
```json
{
  "bucket": "aws-esempio05-lambda-test",
  "path": "folder/subfolder/",
  "count": 2,
  "objects": [
    {
      "key": "folder/subfolder/file1.txt",
      "size": 1024,
      "last_modified": "2025-10-27T10:00:00+00:00",
      "storage_class": "STANDARD"
    }
  ]
}
```

## Utilizzo

### Inizializzazione

```bash
terraform init
```

### Deploy

```bash
terraform apply -var="bucket_name=my-unique-bucket-name-123"
```

### Test della Lambda

#### 1. Via Function URL (se abilitato)

```bash
# Ottieni Function URL
FUNCTION_URL=$(terraform output -raw lambda_function_url)

# Test senza path (root bucket)
curl "$FUNCTION_URL"

# Test con path specifico
curl "$FUNCTION_URL?path=test/"
```

#### 2. Via AWS CLI

```bash
# Invoca Lambda direttamente
aws lambda invoke \
  --function-name s3-list-objects-function \
  --payload '{"path": "test/"}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

#### 3. Upload file di test nel bucket

```bash
# Crea file di test
echo "Test file 1" > test1.txt
echo "Test file 2" > test2.txt

# Upload nel bucket
aws s3 cp test1.txt s3://my-unique-bucket-name-123/test/
aws s3 cp test2.txt s3://my-unique-bucket-name-123/test/subfolder/

# Testa la Lambda
curl "$FUNCTION_URL?path=test/"
```

### Con Lambda personalizzata

Per usare codice Lambda personalizzato, crea un file `lambda_function.py`:

```python
import json
import boto3

def lambda_handler(event, context):
    # Il tuo codice qui
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
```

Poi modifica il terraform:

```hcl
# In terraform.tfvars
lambda_code = file("lambda_function.py")
```

### Con VPC

```bash
terraform apply \
  -var="bucket_name=my-bucket-123" \
  -var='vpc_subnet_ids=["subnet-xxx","subnet-yyy"]' \
  -var='vpc_security_group_ids=["sg-xxx"]'
```

### Con Dead Letter Queue

Prima crea una SQS queue:

```bash
aws sqs create-queue --queue-name lambda-dlq
```

Poi:

```bash
terraform apply \
  -var="bucket_name=my-bucket-123" \
  -var="dead_letter_queue_arn=arn:aws:sqs:eu-central-1:123456789012:lambda-dlq"
```

### Con CloudWatch Alarms

```bash
# Prima crea SNS topic
aws sns create-topic --name lambda-alerts

terraform apply \
  -var="bucket_name=my-bucket-123" \
  -var="enable_error_alarm=true" \
  -var="enable_throttle_alarm=true" \
  -var='alarm_actions=["arn:aws:sns:eu-central-1:123456789012:lambda-alerts"]'
```

## Monitoring

### CloudWatch Logs

```bash
# Visualizza log in tempo reale
aws logs tail /aws/lambda/s3-list-objects-function --follow

# Query log
aws logs filter-log-events \
  --log-group-name /aws/lambda/s3-list-objects-function \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

### Metriche CloudWatch

```bash
# Invocazioni
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=s3-list-objects-function \
  --start-time $(date -u -d '1 hour ago' --iso-8601) \
  --end-time $(date -u --iso-8601) \
  --period 300 \
  --statistics Sum

# Errori
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=s3-list-objects-function \
  --start-time $(date -u -d '1 hour ago' --iso-8601) \
  --end-time $(date -u --iso-8601) \
  --period 300 \
  --statistics Sum
```

## Lambda Configuration

### Runtime supportati
- Python: 3.11, 3.10, 3.9
- Node.js: 20.x, 18.x
- Java: 21, 17, 11, 8
- .NET: 8, 6
- Go: 1.x
- Ruby: 3.2

### Memory e CPU
- Memory: 128 MB - 10.240 MB
- CPU: Proporzionale alla memory
  - 128 MB = ~0.08 vCPU
  - 1.024 MB = ~0.6 vCPU
  - 1.769 MB = 1 vCPU
  - 10.240 MB = 6 vCPU

### Timeout
- Default: 3 secondi
- Massimo: 15 minuti (900 secondi)

## Costi

### Lambda Pricing (eu-central-1)
- **Richieste**: $0.20 per milione
- **Duration**: $0.0000166667 per GB-secondo
- **Free tier**: 
  - 1M richieste/mese gratis
  - 400.000 GB-secondi/mese gratis

### Esempio calcolo (128 MB, 1M invocazioni/mese, 200ms avg)
- Richieste: 1M × $0.20/M = $0.20
- Duration: 1M × 0.2s × 0.128GB × $0.0000166667 = $0.43
- **Totale**: ~$0.63/mese
- **Con free tier**: $0/mese

### S3 costs
- Storage: $0.023/GB/mese
- Requests GET: $0.0004/1000
- 10 GB + 100K requests = ~$0.27/mese

## Best Practices

1. **Memory optimization**: Testa diverse configurazioni
2. **Timeout appropriato**: Non troppo alto
3. **Error handling**: Gestire eccezioni
4. **Logging**: Log strutturato (JSON)
5. **Environment variables**: Per configurazione
6. **Least privilege**: IAM policies minimali
7. **Versioning**: Usare alias e versioni
8. **Monitoring**: CloudWatch alarms
9. **Dead Letter Queue**: Per errori critici
10. **Cold start**: Minimizzare dipendenze

## Lambda Layers

Per aggiungere dipendenze comuni:

```bash
# Crea layer per requests library
mkdir python
pip install requests -t python/
zip -r requests-layer.zip python
rm -rf python

# Pubblica layer
aws lambda publish-layer-version \
  --layer-name requests-lib \
  --zip-file fileb://requests-layer.zip \
  --compatible-runtimes python3.11

# Usa nel Terraform
terraform apply -var='lambda_layers=["arn:aws:lambda:eu-central-1:123456789012:layer:requests-lib:1"]'
```

## Troubleshooting

### Lambda non ha permessi S3
Verifica IAM role e policy. Controlla CloudWatch Logs per errori.

### Timeout
Aumenta `lambda_timeout` o ottimizza codice.

### Out of memory
Aumenta `lambda_memory_size`.

### VPC Lambda non raggiunge S3
- Aggiungi S3 VPC Endpoint
- O usa NAT Gateway

### Function URL non funziona
- Verifica `authorization_type = "NONE"`
- Controlla CORS configuration

## Output

- `lambda_function_name`: Nome della Lambda
- `lambda_function_arn`: ARN della Lambda
- `lambda_function_invoke_arn`: Invoke ARN
- `lambda_function_url`: Function URL (se abilitato)
- `bucket_name`: Nome del bucket S3
- `log_group_name`: Nome log group
- `test_curl_command`: Comando curl per test

## Distruzione

```bash
# Svuota bucket prima
aws s3 rm s3://my-bucket-123 --recursive

terraform destroy
```

## Sicurezza

1. **Function URL**: Usare `AWS_IAM` auth in produzione
2. **Secrets**: Usare AWS Secrets Manager
3. **VPC**: Isolare in VPC se necessario
4. **Encryption**: Abilitare encryption at-rest
5. **IAM**: Least privilege principle
6. **Versioning**: Usare versioni immutabili
7. **Logging**: Non loggare dati sensibili

## Riferimenti

- [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [Python Runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
