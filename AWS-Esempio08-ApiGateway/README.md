# AWS Esempio 08 - API Gateway REST API

Questo esempio mostra come creare un'API Gateway REST con due endpoint che integrano Lambda Functions per diverse operazioni: listing di file S3 e calcolo matematico.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Architettura API**
1. Client HTTP invia richiesta GET /files
2. API Gateway autentica e valida la richiesta
3. API Gateway invoca Lambda "list-files" tramite proxy integration
4. Lambda lista gli oggetti nel bucket S3
5. Response JSON con lista file ritorna al client

Oppure:
1. Client HTTP invia richiesta POST /calculate con body JSON
2. API Gateway valida il payload
3. API Gateway invoca Lambda "calculate-hypotenuse"
4. Lambda calcola l'ipotenusa dati due cateti
5. Response JSON con risultato calcolo

**File di progetto**
- `main.tf`: Definizione risorse AWS (API Gateway, Lambda, S3, IAM, CloudWatch)
- `variables.tf`: Variabili configurabili (nomi, stage, autenticazione, CORS, usage plan)
- `outputs.tf`: Output utili (URL endpoints, comandi test, API key)
- `backend.tf`: Configurazione backend remoto S3
- `lambda_list_files.py`: Codice Python della Lambda per listare file S3 (GET /files)
- `lambda_calculate_hypotenuse.py`: Codice Python della Lambda per calcolo ipotenusa (POST /calculate)

**Risorse create**
- API Gateway REST API: API con configurazione regionale ed endpoint personalizzati
- API Gateway Resources: /files e /calculate paths
- API Gateway Methods: GET /files e POST /calculate
- API Gateway Integrations: Proxy integration con Lambda Functions
- API Gateway Deployment & Stage: Deploy con stage configurabile (default: prod)
- Lambda Functions: 2 functions (list-files per S3, calculate-hypotenuse per calcolo)
- S3 Bucket: Bucket per storage file accessibili via GET endpoint
- IAM Roles & Policies: Permessi Lambda per S3 e CloudWatch Logs
- Lambda Permissions: Permessi API Gateway per invocare Lambda
- CloudWatch Log Groups: Logs per API Gateway e Lambda Functions
- Usage Plan (opzionale): Rate limiting e quota per protezione API
- API Key (opzionale): Chiave per autenticazione richieste
- CORS Configuration (opzionale): OPTIONS method per Cross-Origin requests
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio08ApiGateway/terraform.tfstate`.

**Prerequisiti**
- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)
- AWS CLI per testing (opzionale)
- curl o tool simile per test HTTP

**Costi stimati**
- API Gateway: $3.50 per milione richieste (primo milione gratis nel free tier)
- Lambda: $0.20 per milione richieste + $0.0000166667 per GB-secondo
- S3: $0.023 per GB storage + $0.005 per 1.000 richieste GET
- CloudWatch Logs: $0.50 per GB ingested
- Costo medio esempio: ~$0.01-0.05/giorno con uso moderato

## Comandi
- Creazione infrastruttura
  ```bash
  # Inizializzazione
  terraform init

  # Preview modifiche
  terraform plan

  # Deploy base
  terraform apply
  ```
  - Deploy alternativi/avanzati
    ```
    # Deploy con API key abilitata
    terraform apply \
      -var="api_key_required=true" \
      -var="create_usage_plan=true"

    # Deploy con custom settings
    terraform apply \
      -var="api_name=my-api" \
      -var="bucket_name=my-api-files-bucket" \
      -var="stage_name=dev" \
      -var="enable_xray_tracing=true" \
      -var="quota_limit=5000" \
      -var="throttle_rate_limit=100"
    ```
- Test degli endpoint

  ```bash
  # Salva URL in variabili
  API_URL=$(terraform output -raw api_endpoint)
  GET_URL=$(terraform output -raw get_files_url)
  POST_URL=$(terraform output -raw post_calculate_url)

  # Carica file di test in S3
  BUCKET_NAME=$(terraform output -raw bucket_name)
  echo "Test file 1" > /tmp/test1.txt
  echo "Test file 2" > /tmp/test2.txt
  aws s3 cp /tmp/test1.txt s3://$BUCKET_NAME/test1.txt
  aws s3 cp /tmp/test2.txt s3://$BUCKET_NAME/folder/test2.txt

  # Test GET /files - Lista file S3
  curl $GET_URL | jq

  # Test GET con API Key (se abilitata)
  API_KEY=$(terraform output -raw api_key)
  curl -H "x-api-key: $API_KEY" $GET_URL | jq

  # Test POST /calculate - Calcolo ipotenusa
  curl -X POST $POST_URL \
    -H 'Content-Type: application/json' \
    -d '{"cateto_a":3,"cateto_b":4}' | jq

  curl -X POST $POST_URL \
    -H 'Content-Type: application/json' \
    -d '{"cateto_a":5,"cateto_b":12}' | jq

  # Test POST con valori non validi
  curl -X POST $POST_URL \
    -H 'Content-Type: application/json' \
    -d '{"cateto_a":-3,"cateto_b":4}' | jq

  # Test con header verbose
  curl -v $GET_URL
  ```
- Monitoraggio e debugging

  ```bash
  # Visualizza logs Lambda list-files
  aws logs tail /aws/lambda/alnao-terraform-aws-esempio08-api-list-files --follow

  # Visualizza logs Lambda calculate
  aws logs tail /aws/lambda/alnao-terraform-aws-esempio08-api-calculate-hypotenuse --follow

  # Visualizza logs API Gateway
  aws logs tail /aws/apigateway/alnao-terraform-aws-esempio08-api --follow

  # Query logs recenti
  aws logs filter-log-events \
    --log-group-name /aws/apigateway/alnao-terraform-aws-esempio08-api \
    --start-time $(date -d '10 minutes ago' +%s)000 \
    --filter-pattern "{ $.status = 500 }"

  # Metriche API Gateway
  aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Count \
    --dimensions Name=ApiName,Value=alnao-terraform-aws-esempio08-api \
    --start-time $(date -u -d '1 hour ago' --iso-8601) \
    --end-time $(date -u --iso-8601) \
    --period 300 \
    --statistics Sum

  # Metriche errori 4XX
  aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name 4XXError \
    --dimensions Name=ApiName,Value=alnao-terraform-aws-esempio08-api \
    --start-time $(date -u -d '1 hour ago' --iso-8601) \
    --end-time $(date -u --iso-8601) \
    --period 300 \
    --statistics Sum

  # Latenza media API
  aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Latency \
    --dimensions Name=ApiName,Value=alnao-terraform-aws-esempio08-api \
    --start-time $(date -u -d '1 hour ago' --iso-8601) \
    --end-time $(date -u --iso-8601) \
    --period 300 \
    --statistics Average,Maximum

  # Lambda invocations
  aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=alnao-terraform-aws-esempio08-api-list-files \
    --start-time $(date -u -d '1 hour ago' --iso-8601) \
    --end-time $(date -u --iso-8601) \
    --period 300 \
    --statistics Sum
  ```

- Gestione Usage Plan e API Key

  ```bash
  # Lista usage plans
  aws apigateway get-usage-plans

  # Verifica utilizzo corrente
  USAGE_PLAN_ID=$(aws apigateway get-usage-plans \
    --query 'items[?name==`esempio08-api-usage-plan`].id' \
    --output text)

  aws apigateway get-usage \
    --usage-plan-id $USAGE_PLAN_ID \
    --start-date $(date -d '7 days ago' +%Y-%m-%d) \
    --end-date $(date +%Y-%m-%d)

  # Esporta API definition
  API_ID=$(terraform output -raw api_id)
  aws apigateway get-export \
    --rest-api-id $API_ID \
    --stage-name prod \
    --export-type swagger \
    swagger.json

  # Testa throttling (richiede API key e usage plan)
  for i in {1..200}; do
    curl -H "x-api-key: $API_KEY" $GET_URL &
  done
  wait
  ```
- Load testing

  ```bash
  # Install apache bench se necessario
  # sudo apt-get install apache2-utils

  # Test carico GET endpoint
  ab -n 1000 -c 10 $GET_URL

  # Test carico POST endpoint
  ab -n 1000 -c 10 -p <(echo '{"cateto_a":3,"cateto_b":4}') \
    -T 'application/json' $POST_URL

  # Test con hey (alternativa moderna)
  # go install github.com/rakyll/hey@latest
  hey -n 1000 -c 10 $GET_URL
  ```

- Distruzione risorse

  ```bash
  # Svuota bucket S3 prima di destroy
  BUCKET_NAME=$(terraform output -raw bucket_name)
  aws s3 rm s3://$BUCKET_NAME --recursive

  # Destroy infrastruttura
  terraform destroy

  ```

## Riferimenti
- [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [API Gateway REST API Reference](https://docs.aws.amazon.com/apigateway/latest/api/API_Operations.html)
- [Lambda Proxy Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html)
- [API Gateway Pricing](https://aws.amazon.com/api-gateway/pricing/)
- [API Gateway Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/best-practices.html)
- [Throttling API Requests](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html)

