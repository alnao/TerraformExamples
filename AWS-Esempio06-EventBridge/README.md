# AWS Esempio 06 - EventBridge con Lambda

Questo esempio mostra come usare Amazon EventBridge per triggerare automaticamente una Lambda function quando un file viene caricato in un bucket S3.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**
- S3 Bucket: Bucket sorgente che genera eventi
- S3 Bucket Notification: Configurazione EventBridge per S3
- Lambda Function: Function che processa gli eventi
- IAM Role & Policies: Permessi per Lambda
- EventBridge Rule: Rule per catturare eventi S3 Object Created
- EventBridge Target: Target Lambda per la rule
- Lambda Permission: Permesso per EventBridge di invocare Lambda
- CloudWatch Log Group: Log della Lambda
- CloudWatch Alarms: (Opzionale) Alert per errori
- SQS Dead Letter Queue: (Opzionale) Per eventi falliti
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio06EventBridge/terraform.tfstate`.

**Prerequisiti**
- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)

**Costi**
- EventBridge: $1.00 per milione eventi
- Lambda: $0.20 per milione richieste + $0.0000166667 per GB-s
- S3: Storage + requests standard
- CloudWatch Logs: $0.50 per GB ingested


## Comandi
- Creazione
  ```bash
  NOME_BUCKET="alnao-terraform-aws-esempio06-eventbridge-bucket"
  terraform init
  terraform plan
  terraform apply -var="source_bucket_name=$NOME_BUCKET"
  ```
- Test

  ```bash
  # Upload file di test
  echo "Hello World" > /tmp/test.txt
  aws s3 cp /tmp/test.txt s3://$NOME_BUCKET/test.txt

  # Visualizza logs Lambda
  aws logs tail /aws/lambda/alnao-terraform-aws-esempio06-eventbridge-lambda --follow

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
- Distruzione
  ```bash
  # Svuota bucket prima
  aws s3 rm s3://$NOME_BUCKET --recursive

  terraform destroy
  ```



## Riferimenti

- [EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/)
- [S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventBridge.html)
- [EventBridge Pricing](https://aws.amazon.com/eventbridge/pricing/)
