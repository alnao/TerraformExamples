# Azure Esempio 09 - CosmosDB con MongoDB API

Questo esempio mostra come creare un database Azure CosmosDB for MongoDB vCore con Terraform, con integrazione Azure Function App + Blob Storage come sistema event-driven per salvare metadati in MongoDB.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attenzione prima di eseguire qualsiasi comando ⚠️

**Architettura**
1. File viene caricato nel container Blob Storage "uploads"
2. Azure Function (Blob Trigger) si attiva automaticamente
3. La Function legge i metadati del blob
4. Salva i metadati nella collection MongoDB `blob_metadata`
5. Application Insights (opzionale) raccoglie log e metriche
6. Event Grid System Topic (opzionale) monitora gli eventi blob
7. Azure Monitor Alert (opzionale) notifica su soglie di richieste
8. Key Vault salva connection string, username e password

**File di progetto**
- `main.tf`: CosmosDB Mongo vCore Cluster + Key Vault + Private Endpoint + firewall rule
- `compute.tf`: Storage Account + Azure Function App (Blob Trigger) + App Insights + Event Grid + Monitor Alerts
- `variables.tf`: Tutte le variabili configurabili
- `outputs.tf`: Output utili (connection string, function app name, storage account, ...)
- `backend.tf`: Configurazione backend remoto Azure Storage
- `data.tf`: Data sources per Private Endpoint (VNet, Subnet, DNS Zone)
- `terraform.tfvars.example`: Esempio di configurazione da copiare in `terraform.tfvars`
- `function_app/function_app.py`: Codice Python Azure Function con Blob Trigger → CosmosDB
- `function_app/host.json`: Configurazione host Azure Functions v4
- `function_app/requirements.txt`: Dipendenze Python della Function App
- `test.py`: Script di test con auto-detect della connection string

**Mapping AWS → Azure (rispetto ad AWS-Esempio09-DynamoDB)**

| AWS Resource | Azure Resource | Note |
|---|---|---|
| `aws_dynamodb_table` | `azurerm_mongo_cluster` | CosmosDB MongoDB vCore |
| `aws_s3_bucket` | `azurerm_storage_account` + container | Blob Storage |
| `aws_lambda_function` | `azurerm_linux_function_app` | Consumption plan (Y1) |
| EventBridge Rule | Blob Trigger binding | Integrato nel Function App |
| `aws_iam_role` | System Managed Identity | Identità gestita Azure |
| CloudWatch Log Group | `azurerm_application_insights` + Log Analytics | Telemetria e log |
| CloudWatch Alarm | `azurerm_monitor_metric_alert` | Alert su metriche |
| DynamoDB Streams | Change Feed (`preview_features`) | Event sourcing |
| Global Tables | high_availability_mode + geo-replica | Non in free tier |
| — | `azurerm_key_vault` | Bonus: vault per secrets |

**Risorse create**
- **Resource Group**: Gruppo di risorse dedicato
- **Cosmos DB Mongo Cluster** (vCore, Free Tier):
  - Free tier: 32 GB storage incluso (1 per subscription)
  - Change Feed opzionale (equivalente a DynamoDB Streams)
  - Firewall rule opzionale per IP specifico (via null_resource + Azure CLI)
  - Private Endpoint opzionale (accesso privato tramite VNet)
- **Azure Key Vault** (opzionale):
  - Salva connection string, username e password come secrets
- **Compute system** (opzionale, `enable_blob_function_integration = true`):
  - Storage Account con container "uploads" (trigger) e "deleted-tracking" (opzionale)
  - App Service Plan Consumption (Y1, serverless)
  - Linux Function App Python 3.11 con Blob Trigger
  - Application Insights + Log Analytics Workspace (opzionale)
  - Event Grid System Topic per monitoraggio eventi blob (opzionale)
  - Azure Monitor Metric Alert per richieste CosmosDB (opzionale)

**Prerequisiti**
- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva
- Python 3.11+ per lo script di test (`pip install pymongo`)

**Variabili principali**

| Variabile | Default | Descrizione | AWS equivalente |
|---|---|---|---|
| `subscription_id` | null | ID subscription Azure | — |
| `cosmosdb_account_name` | `alnao-terraform-esempio09-...` | Nome cluster | `table_name` |
| `compute_tier` | `Free` | Tier cluster | `billing_mode` |
| `mongodb_version` | `5.0` | Versione MongoDB | — |
| `enable_change_feed` | false | Change Streams | `stream_enabled` |
| `enable_blob_function_integration` | true | Function + Storage | `enable_s3_lambda_integration` |
| `storage_account_name` | `alnaoterrafes09func` | Nome storage | `table_name}-trigger-bucket` |
| `function_app_name` | `alnao-terraform-es09-func` | Nome function | Lambda function name |
| `enable_delete_tracking` | false | Track delete events | `enable_delete_tracking` |
| `enable_application_insights` | false | App Insights | CloudWatch Log Group |
| `enable_event_grid` | false | Event Grid Topic | EventBridge |
| `enable_monitor_alerts` | false | Monitor Alerts | `enable_cloudwatch_alarms` |
| `enable_key_vault` | true | Key Vault | — (bonus) |
| `enable_firewall_rule` | false | Firewall rule IP | — |
| `my_ip_address` | `0.0.0.0` | IP da autorizzare | — |


## Comandi

- Inizializzazione:
  ```bash
  # Login Azure e impostazione subscription (una volta sola, come gli altri esempi Azure)
  az login
  export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

  cp terraform.tfvars.example terraform.tfvars
  # Modifica terraform.tfvars con la password MongoDB
  terraform init
  terraform plan
  ```

- Deploy base (solo CosmosDB, Key Vault):
  ```bash
  terraform apply
  ```

- Deploy completo con Function App + Application Insights:
  ```bash
  terraform apply \
    -var="enable_blob_function_integration=true" \
    -var="enable_application_insights=true"
  ```

- Deploy con Event Grid e Monitor Alerts:
  ```bash
  terraform apply \
    -var="enable_blob_function_integration=true" \
    -var="enable_event_grid=true" \
    -var="enable_monitor_alerts=true"
  ```

- Deploy con Change Feed (equivalente a DynamoDB Streams):
  ```bash
  terraform apply -var="enable_change_feed=true"
  ```

- Apertura firewall per il proprio IP:
  ```bash
  terraform apply \
    -var="enable_firewall_rule=true" \
    -var="my_ip_address=$(curl -s ifconfig.me)"
  ```
  Oppure manualmente via Azure CLI:
  ```bash
  MYIP=$(curl -s ifconfig.me)
  az cosmosdb mongocluster firewall rule create \
    --cluster-name alnao-terraform-esempio09-cosmosmongo \
    --resource-group alnao-terraform-esempio09-cosmosmongo \
    --rule-name AllowMyIP \
    --start-ip-address $MYIP \
    --end-ip-address $MYIP
  ```

- Test con script Python (auto-detect connection string):
  ```bash
  pip install pymongo
  python3 test.py                    # Insert + find (default)
  python3 test.py --list             # Lista database e collections
  python3 test.py --insert           # Inserisce documento di prova
  python3 test.py --find             # Mostra documenti
  python3 test.py --drop             # Elimina la collection
  python3 test.py -c "mongodb+srv://..."  # Connection string manuale
  ```
  La connection string viene recuperata automaticamente nell'ordine:
  1. `--connection-string` / `-c`
  2. Variabile d'ambiente `COSMOSDB_CONNECTION_STRING`
  3. `terraform output cosmosdb_connection_strings`
  4. Azure Key Vault tramite `az keyvault secret show`

- Test upload blob → Function → CosmosDB (≈ test S3 → Lambda → DynamoDB di AWS):
  ```bash
  # Upload blob nel container "uploads" (trigger della Function)
  STORAGE_NAME=$(terraform output -raw storage_account_name)
  az storage blob upload \
    --account-name $STORAGE_NAME \
    --container-name uploads \
    --name test-file.txt \
    --data "Test content from Azure CLI"

  # Verifica metadati salvati in CosmosDB
  python3 test.py --find --collection blob_metadata

  # Visualizza log della Function App
  FUNC_NAME=$(terraform output -raw function_app_name)
  az functionapp log tail --name $FUNC_NAME \
    --resource-group alnao-terraform-esempio09-cosmosmongo
  ```

- Recupero connection string manuale:
  ```bash
  # Da Key Vault
  az keyvault secret show \
    --vault-name alnao-terraform-es9-key \
    --name cosmosdb-mongodb-connection-string \
    --query value -o tsv

  # Da Terraform output
  terraform output -json cosmosdb_connection_strings
  ```

- Verifica stato cluster:
  ```bash
  az extension add --name cosmosdb-preview
  az cosmosdb mongocluster list \
    --resource-group alnao-terraform-esempio09-cosmosmongo
  ```

- Connessione con mongosh:
  ```bash
  mongosh "mongodb+srv://<credentials>@alnao-terraform-esempio09-cosmosmongo.mongocluster.cosmos.azure.com/?authMechanism=SCRAM-SHA-256&retrywrites=false&maxIdleTimeMS=120000"
  ```

- Comandi MongoDB da console/mongosh:
  ```
  show databases
  use esempio09db
  show collections
  db.annotazioni.find()
  db.blob_metadata.find()
  ```

- Output Terraform:
  ```bash
  terraform output -json
  terraform output cosmosdb_mongo_cluster_name
  terraform output key_vault_uri
  terraform output function_app_name
  terraform output storage_account_name
  terraform output query_cosmosdb_command
  terraform output test_upload_command
  ```

- Distruzione:
  ```bash
  terraform destroy
  ```
  Nota: la firewall rule viene rimossa automaticamente dal provisioner `local-exec` di destroy.


## Costi esempio

- **Free Tier** (compute_tier = "Free"):
  - 32 GB storage: gratuito
  - 1 cluster free per subscription
  - **Totale**: €0/mese

- **Provisioned M25** (~equivalente a DynamoDB PROVISIONED 400 RU/s):
  - Compute M25: ~€50-70/mese
  - Storage 32 GB: ~€7/mese
  - **Totale**: ~€57-77/mese

- **Azure Function** (Consumption Plan):
  - 1M esecuzioni/mese gratuite
  - Oltre: ~€0.20 per milione di esecuzioni
  - **Totale**: praticamente gratuito per test

- **Application Insights + Log Analytics**:
  - 5 GB/mese dati gratuiti
  - Oltre: €2.30/GB
  - **Totale**: €0-5/mese per workload dev

- **Key Vault**:
  - 10.000 operazioni/mese gratuite
  - **Totale**: praticament €0 per test


## Differenze con DynamoDB (AWS-Esempio09)

| Feature | CosmosDB Mongo vCore | DynamoDB |
|---------|----------------------|----------|
| API | MongoDB nativa | Proprietaria (+PartiQL) |
| Free Tier | 32 GB (1 per sub) | 25 GB + 25 RCU/WCU |
| Scalabilità | Compute tier upgrade | PAY_PER_REQUEST / PROVISIONED |
| Autoscaling | Cambio tier manuale | Application Auto Scaling |
| Streams/CDC | Change Feed (preview) | DynamoDB Streams |
| Multi-region | HA zones / geo-replica | Global Tables |
| Encryption | Azure-managed (always on) | AWS-managed o CMK |
| TTL | TTL index MongoDB | TTL nativo DynamoDB |
| Backup | Continuo (automatico) | PITR (da abilitare) |
| Trigger | Blob Trigger (Function) | Lambda via EventBridge |
| Secret store | Key Vault (incluso) | Non nativo |
| Max item size | 16 MB (MongoDB) | 400 KB |


## Riferimenti

- [Azure CosmosDB for MongoDB vCore](https://learn.microsoft.com/azure/cosmos-db/mongodb/vcore/)
- [Terraform azurerm_mongo_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mongo_cluster)
- [Azure Functions Blob Trigger](https://learn.microsoft.com/azure/azure-functions/functions-bindings-storage-blob-trigger)
- [Azure Functions Python v2](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)
- [PyMongo Documentation](https://pymongo.readthedocs.io/)
- [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview)
- [Azure Monitor Metric Alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-metric)
- [Azure Event Grid](https://learn.microsoft.com/azure/event-grid/overview)
- [Prezzi CosmosDB](https://azure.microsoft.com/pricing/details/cosmos-db/)
- [Prezzi Azure Functions](https://azure.microsoft.com/pricing/details/functions/)


# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella misura massima possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale.

Alcuni contenuti e porzioni di codice presenti in questo repository sono stati realizzati anche grazie al supporto di strumenti di intelligenza artificiale, il cui contributo ha permesso di arricchire e velocizzare la produzione del materiale. Ogni informazione e frammento di codice è stato comunque attentamente verificato e validato, con l'obiettivo di garantire la massima qualità e affidabilità dei contenuti offerti.

Per ulteriori dettagli, approfondimenti o richieste di chiarimento, si invita a consultare il sito [AlNao.it](https://www.alnao.it/).

## License
Made with ❤️ by <a href="https://www.alnao.it">AlNao</a>
&bull;
Public projects
<a href="https://www.gnu.org/licenses/gpl-3.0" valign="middle"> <img src="https://img.shields.io/badge/License-GPL%20v3-blue?style=plastic" alt="GPL v3" valign="middle" /></a>
*Free Software!*

Il software è distribuito secondo i termini della GNU General Public License v3.0. L'uso, la modifica e la ridistribuzione sono consentiti, a condizione che ogni copia o lavoro derivato sia rilasciato con la stessa licenza. Il contenuto è fornito "così com'è", senza alcuna garanzia, esplicita o implicita.



