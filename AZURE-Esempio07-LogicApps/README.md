# AZURE Esempio 07 - Logic Apps

Logic App completa che copia blob da storage source a destination e invoca una Function App per il logging delle operazioni.

⚠️ **Nota importante**: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attenzione prima di eseguire qualsiasi comando ⚠️

## Architettura

```
Storage Source → Logic App Trigger → Copy Blob → Storage Destination
                                   ↓
                              Function App Logger
                                   ↓
                            Application Insights
```

## Risorse Create

- **Resource Group**: contenitore per tutte le risorse
- **Log Analytics Workspace**: storage per log di Application Insights (retention 30 giorni)
- **Application Insights**: monitoring e logging centralizzato
- **3 Storage Accounts**:
  - `source`: storage di origine con container "source"
  - `destination`: storage di destinazione con container "destination"  
  - `function`: storage per la Function App e deploy del codice
- **Logic App Workflow**: workflow base (da completare manualmente nel portale)
- **Function App**: Azure Function Python 3.11 per logging HTTP-triggered
- **API Connection**: connessione Azure Blob per Logic App
- **Role Assignments**: permessi RBAC per accesso agli storage

## File del Progetto

### Terraform
- `main.tf`: configurazione Terraform principale con deploy automatico del codice
- `variables.tf`: variabili configurabili
- `outputs.tf`: output utili post-deployment
- `backend.tf`: configurazione backend remoto
- `terraform.tfvars.example`: template per personalizzare le variabili

### Function App
- `function_app.py`: codice Python della Function App con 2 endpoint HTTP
- `requirements.txt`: dipendenze Python (azure-functions)
- `host.json`: configurazione runtime Azure Functions v2

### Logic App
- `logic_app_workflow.json`: definizione completa del workflow JSON (solo riferimento)
- `configure_logic_app.sh`: script helper per configurazione workflow

### Utility
- `deploy.sh`: script bash per deploy automatico con validazioni
- `test_function.py`: script Python per test locale della funzione
- `.gitignore`: esclusioni Git per Terraform e Python

## Workflow Logic App

1. **Trigger**: monitoraggio container `source` ogni minuto per nuovi blob
2. **Action 1**: copia blob dal container source al container destination
3. **Action 2**: chiamata HTTP POST alla Function App con dettagli operazione

## Function App

La funzione espone 2 endpoint:
- `POST /api/logger`: riceve dettagli copia blob e registra in Application Insights
- `GET /api/health`: health check

Payload di esempio per `/api/logger`:
```json
{
  "blobName": "test.txt",
  "sourceContainer": "source",
  "destinationContainer": "destination",
  "operationTime": "2026-02-12T10:30:00Z"
}
```

## Prerequisiti

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) >= 2.40
- Subscription Azure attiva
- Permessi per creare risorse

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

⚠️ **Nota Importante**: A causa di limitazioni del provider Terraform AzureRM, il workflow Logic App (trigger e actions) deve essere configurato **manualmente** dopo il deploy tramite il portale Azure.

## Utilizzo

### 1. Deploy Infrastruttura

```bash
chmod +x deploy.sh
./deploy.sh
```

Oppure manualmente:
```bash
terraform init
terraform plan
terraform apply
```

### 2. Configura Logic App Workflow

```bash
chmod +x configure_logic_app.sh
./configure_logic_app.sh
```

Lo script mostra le istruzioni per configurare il workflow nel portale Azure.

### 3. Test del Workflow

```bash
SOURCE_STORAGE=$(terraform output -raw source_storage_name)
echo $SOURCE_STORAGE
echo "Test $(date)" > test.txt

az storage blob upload \
  --account-name $SOURCE_STORAGE \
  --container-name source \
  --name test.txt \
  --file test.txt \
  --auth-mode login

# Attendi 1 minuto, poi verifica destination
az storage blob list \
  --account-name $(terraform output -raw destination_storage_name) \
  --container-name destination \
  --output table \
  --auth-mode login
```

### 4. Test Function App

```bash
FUNCTION_URL=$(terraform output -raw function_app_url)

# Test logger
curl -X POST "${FUNCTION_URL}/api/logger" \
  -H "Content-Type: application/json" \
  -d '{"blobName":"test.txt","sourceContainer":"source","destinationContainer":"destination","operationTime":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

# Health check
curl "${FUNCTION_URL}/api/health"
```

### 5. Cleanup

```bash
terraform destroy -auto-approve
rm -f function.zip tfplan
```

## Troubleshooting

### Logic App non si triggera
- Verifica API Connection nel portale
- Controlla Run History per errori
- Verifica RBAC: `az role assignment list --scope ...`

### Function App non risponde
```bash
az functionapp function sync --name func-logger-07 --resource-group alnao-terraform-esempio07-logicapps
az webapp log tail --name func-logger-07 --resource-group alnao-terraform-esempio07-logicapps
```

### State Terraform bloccato
```bash
terraform force-unlock <LOCK_ID>
```

## Costi Stimati

- Logic App: ~€0.000125/esecuzione
- Function App: ~€0.000014/esecuzione  
- Storage LRS: ~€0.018/GB/mese
- Application Insights: primi 5GB/mese gratuiti

**Totale**: < €5/mese per uso development/test

## Riferimenti

- [Azure Logic Apps](https://docs.microsoft.com/azure/logic-apps/)
- [Azure Functions Python](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
