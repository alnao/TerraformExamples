# AWS Esempio 06 - EventBridge con Lambda

Questo esempio mostra come usare Amazon EventBridge per triggerare automaticamente una Lambda function quando un file viene caricato in un bucket S3.

## Risorse create

- **S3 Bucket**: Bucket sorgente che genera eventi
- **S3 Bucket Notification**: Configurazione EventBridge per S3
- **Lambda Function**: Function che processa gli eventi
- **IAM Role & Policies**: Permessi per Lambda
- **EventBridge Rule**: Rule per catturare eventi S3 Object Created
- **EventBridge Target**: Target Lambda per la rule
- **Lambda Permission**: Permesso per EventBridge di invocare Lambda
- **CloudWatch Log Group**: Log della Lambda
- **CloudWatch Alarms**: (Opzionale) Alert per errori
- **SQS Dead Letter Queue**: (Opzionale) Per eventi falliti
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio06EventBridge/terraform.tfstate`.


## Prerequisiti

- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)
## Caratteristiche

✅ **Event-Driven Architecture** con EventBridge  
✅ **S3 Event Notifications** tramite EventBridge  
✅ **Lambda Processing** automatico al caricamento file  
✅ **Pattern Matching** per filtrare eventi specifici  
✅ **Input Transformer** per personalizzare payload  
✅ **Retry Policy** configurabile  
✅ **Dead Letter Queue** per eventi falliti  
✅ **CloudWatch Alarms** per monitoring  
✅ **Multiple Triggers** (Create, Delete, etc.)  

## Utilizzo

```bash
terraform init
terraform apply -var="source_bucket_name=my-unique-bucket-123"
```

## Test

```bash
# Upload file di test
echo "Hello World" > test.txt
aws s3 cp test.txt s3://my-unique-bucket-123/test.txt

# Visualizza logs Lambda
aws logs tail /aws/lambda/s3-event-processor --follow

# Visualizza metriche EventBridge
aws cloudwatch get-metric-statistics \
  --namespace AWS/Events \
  --metric-name Invocations \
  --dimensions Name=RuleName,Value=s3-object-created-rule \
  --start-time $(date -u -d '1 hour ago' --iso-8601) \
  --end-time $(date -u --iso-8601) \
  --period 300 \
  --statistics Sum
```

## Costi

- **EventBridge**: $1.00 per milione eventi
- **Lambda**: $0.20 per milione richieste + $0.0000166667 per GB-s
- **S3**: Storage + requests standard
- **CloudWatch Logs**: $0.50 per GB ingested

## Best Practices

1. **Event Patterns**: Filtrare eventi specifici
2. **Retry Policy**: Configurare retry appropriati
3. **DLQ**: Gestire eventi falliti
4. **Monitoring**: CloudWatch alarms
5. **IAM Policies**: Least privilege
6. **Input Transformer**: Semplificare payload Lambda

## Riferimenti

- [EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/)
- [S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventBridge.html)
- [EventBridge Pricing](https://aws.amazon.com/eventbridge/pricing/)
