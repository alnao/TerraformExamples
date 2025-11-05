# AZURE Esempio 05 - Azure Functions

Questo esempio mostra come creare una Azure Function con Terraform che lista i blob in un Azure Storage Container in base al path fornito come parametro.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**
- **Resource Group**: Contenitore per tutte le risorse
- **Storage Account (Function)**: Storage per il codice della Function App
- **Storage Account (Test)**: Storage per testing con container di blob
- **Storage Container**: Container per il codice e per i dati di test
- **Application Insights**: Monitoring e logging
- **Service Plan**: Piano di hosting per la Function App
- **Linux/Windows Function App**: Function App con runtime Python
- **Role Assignment**: Managed Identity con accesso allo Storage
- **Metric Alerts**: (Opzionale) Alert per errori e performance

**Prerequisiti**
- Azure CLI installato e autenticato
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva


**Funzionamento della Function**
1. Riceve una richiesta HTTP con parametro `path` opzionale
2. Lista i blob nel container Azure Storage nel path specificato
3. Ritorna un JSON con lista dei blob e metadata
4. Input Request
  ```http
  GET /api/list-blobs?path=folder/subfolder/ HTTP/1.1
  Host: func-blob-list-05.azurewebsites.net
  x-functions-key: <YOUR_FUNCTION_KEY>
  ```
5. Output Response
  ```json
  {
    "container": "testdata",
    "path": "folder/subfolder/",
    "count": 2,
    "blobs": [
      {
        "name": "folder/subfolder/file1.txt",
        "size": 1024,
        "last_modified": "2025-10-27T10:00:00+00:00",
        "content_type": "text/plain",
        "blob_type": "BlockBlob"
      }
    ]
  }
  ```

## Comandi
- Inizializzazione
  ```bash
  terraform init
  terraform plan
  terraform apply
  ```
  - Deploy con parametri 
    ```bash
    terraform apply \
      -var="storage_account_name=stfuncunique123" \
      -var="test_storage_account_name=sttestunique123" \
      -var="function_app_name=func-blob-list-unique"
    ```
- Deploy del codice Function
  ```bash
  # Ottieni comando di deploy
  DEPLOY_CMD=$(terraform output -raw deploy_command)

  # Esegui deploy
  echo $DEPLOY_CMD
  eval $DEPLOY_CMD

  # Oppure eseguire il comando manualmente
  az functionapp deployment source config-zip \
    -g alnao-terraform-esempio05-functions \
    -n func-blob-list-05 \
    --src function_app.zip
  ```
- Ottieni Function Key
  ```bash
  # List function keys
  az functionapp function keys list \
    -g alnao-terraform-esempio05-functions \
    -n func-blob-list-05 \
    --function-name list-blobs

  # Get default host key
  FUNCTION_KEY=$(az functionapp keys list \
    -g alnao-terraform-esempio05-functions \
    -n func-blob-list-05 \
    --query "functionKeys.default" -o tsv)

  echo $FUNCTION_KEY
  ```
- Test della Function
  1. Via HTTP
    ```bash
    # Ottieni hostname
    HOSTNAME=$(terraform output -raw function_app_hostname)

    # Get function key (come sopra)
    FUNCTION_KEY=$(az functionapp keys list \
      -g alnao-terraform-esempio05-functions \
      -n func-blob-list-05 \
      --query "functionKeys.default" -o tsv)

    # Test senza path
    curl "https://$HOSTNAME/api/list-blobs" \
      -H "x-functions-key: $FUNCTION_KEY"

    # Test con path specifico
    curl "https://$HOSTNAME/api/list-blobs?path=test/" \
      -H "x-functions-key: $FUNCTION_KEY"
    ```
  2. Upload blob di test

    ```bash
    # Ottieni storage account e container
    STORAGE_ACCOUNT=$(terraform output -raw test_storage_account_name)
    CONTAINER=$(terraform output -raw test_container_name)

    # Crea file di test
    echo "Test file 1" > /tmp/test1.txt
    echo "Test file 2" > /tmp/test2.txt

    # Upload blob
    az storage blob upload \
      -f /tmp/test1.txt \
      -c $CONTAINER \
      -n test/test1.txt \
      --account-name $STORAGE_ACCOUNT

    az storage blob upload \
      -f /tmp/test2.txt \
      -c $CONTAINER \
      -n test/subfolder/test2.txt \
      --account-name $STORAGE_ACCOUNT

    # Test function
    curl "https://$HOSTNAME/api/list-blobs?path=test/" -H "x-functions-key: $FUNCTION_KEY"
    ```
- Con Piano Premium
  Per production con Always On e VNet integration:
  ```bash
  terraform apply \
    -var="storage_account_name=stfuncprod123" \
    -var="test_storage_account_name=sttestprod123" \
    -var="function_app_name=func-blob-prod" \
    -var="sku_name=P1V2" \
    -var="always_on=true"
  ```
- Con Metric Alerts
  - Prima crea un Action Group:
    ```bash
    az monitor action-group create \
      -g alnao-terraform-esempio05-functions \
      -n function-alerts \
      --short-name funcalert \
      --email-receiver admin email=admin@example.com
    ```
  - Poi:
    ```bash
    ACTION_GROUP_ID=$(az monitor action-group show \
      -g alnao-terraform-esempio05-functions \
      -n function-alerts \
      --query id -o tsv)

    terraform apply \
      -var="enable_metric_alerts=true" \
      -var="error_alert_threshold=5" \
      -var="response_time_alert_threshold=5" \
      -var="action_group_id=$ACTION_GROUP_ID"
    ```
## Monitoring

### Application Insights

```bash
# Visualizza logs in tempo reale
az monitor app-insights metrics show \
  -g alnao-terraform-esempio05-functions \
  --app func-blob-list-05-insights \
  --metric requests/count

# Query logs
az monitor app-insights query \
  -g alnao-terraform-esempio05-functions \
  --app func-blob-list-05-insights \
  --analytics-query "traces | where message contains 'Listing blobs' | take 10"
```

### Live Metrics Stream

Apri nel portale Azure:
```
Application Insights > Live Metrics
```

### Logs

```bash
# Function logs
az webapp log tail \
  -g alnao-terraform-esempio05-functions \
  -n func-blob-list-05

# Download logs
az webapp log download \
  -g alnao-terraform-esempio05-functions \
  -n func-blob-list-05
```

## Service Plans

### Consumption Plan (Y1)
- **Pricing**: Pay per execution
- **Auto-scaling**: Automatico
- **Timeout**: 5 minuti (default), 10 max
- **Memory**: 1.5 GB
- **Instances**: Max 200
- **Always On**: Non disponibile

### Premium Plan (P1V2)
- **Pricing**: Fisso + pay per execution
- **Pre-warmed instances**: Disponibili
- **Timeout**: 30 minuti (default), illimitato
- **Memory**: 3.5 GB
- **VNet integration**: Disponibile
- **Always On**: Disponibile

### Dedicated Plan (B1, S1, P1V3)
- **Pricing**: Fisso per VM
- **Condivisione**: Con App Service
- **Timeout**: 30 minuti (default), illimitato
- **Always On**: Disponibile

## Costi

### Consumption Plan (Y1)
- **Executions**: €0.169 per milione
- **Execution time**: €0.000014/GB-s
- **Free grant**: 
  - 1M executions/mese
  - 400.000 GB-s/mese
  
### Esempio (1M req/mese, 512MB, 1s avg)
- Executions: (1M - 1M free) = €0
- GB-s: (1M × 1s × 0.5GB - 400K) = 100K × €0.000014 = €1.40
- **Totale**: ~€1.40/mese

### Premium P1V2
- ~€134/mese (1 instance)
- Includes 1M executions gratis

### Storage costs
- General Purpose v2: €0.018/GB/mese
- Operations: €0.004/10K
- 10 GB + 100K ops = ~€0.22/mese

### Application Insights
- Data ingestion: €2.30/GB dopo 5GB gratis
- ~1-2 GB/mese per function attiva = ~€0-2/mese

## Best Practices

1. **Consumption Plan**: Per workload intermittenti
2. **Premium Plan**: Per production con cold start SLA
3. **Dedicated Plan**: Per integrazione con App Service
4. **Managed Identity**: Evitare connection string
5. **Application Insights**: Sempre abilitato
6. **CORS**: Configurare correttamente
7. **Function Keys**: Ruotare regolarmente
8. **Durable Functions**: Per orchestrazioni complesse
9. **Deployment slots**: Per blue-green deployment
10. **VNet integration**: Per risorse private

## Python Function Structure

### Directory structure
```
FunctionApp/
├── host.json
├── requirements.txt
├── list-blobs/
│   ├── __init__.py
│   └── function.json
└── other-function/
    ├── __init__.py
    └── function.json
```

### Trigger types
- **HTTP**: API REST
- **Timer**: Scheduled jobs (cron)
- **Blob**: Quando blob viene creato/modificato
- **Queue**: Messaggi da Storage Queue
- **Event Grid**: Eventi Azure
- **Service Bus**: Messaggi da Service Bus
- **Cosmos DB**: Change feed

## Deploy Options

### 1. Azure CLI (zip deploy)
```bash
az functionapp deployment source config-zip \
  -g resource-group \
  -n function-app \
  --src function.zip
```

### 2. GitHub Actions
```yaml
- uses: Azure/functions-action@v1
  with:
    app-name: 'function-app'
    package: './output'
```

### 3. Azure DevOps
```yaml
- task: AzureFunctionApp@1
  inputs:
    azureSubscription: 'connection'
    appType: 'functionAppLinux'
    appName: 'function-app'
    package: '$(System.DefaultWorkingDirectory)/**/*.zip'
```

### 4. VS Code
- Installa extension "Azure Functions"
- Click destro > Deploy to Function App

## Troubleshooting

### Function non risponde
- Verifica Application Insights logs
- Controlla Function Keys
- Verifica deployment del codice

### Errori di accesso Storage
- Verifica Managed Identity role assignment
- Controlla connection string in app settings
- Verifica firewall storage account

### Cold start lento
- Considera Premium Plan
- Riduci dipendenze Python
- Usa pre-warmed instances

### Out of memory
- Aumenta Service Plan SKU
- Ottimizza codice Python
- Verifica memory leaks

## Sicurezza

1. **Function Keys**: Non committare in git
2. **Managed Identity**: Preferire a connection string
3. **HTTPS only**: Sempre abilitato
4. **VNet integration**: Per risorse private
5. **Storage firewall**: Limitare accesso
6. **App settings**: Non loggare secrets
7. **CORS**: Configurare origins specifici
8. **Azure AD**: Autenticazione per API pubbliche

## Riferimenti

- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Python Developer Guide](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)
- [Functions Pricing](https://azure.microsoft.com/pricing/details/functions/)
- [Best Practices](https://docs.microsoft.com/azure/azure-functions/functions-best-practices)
