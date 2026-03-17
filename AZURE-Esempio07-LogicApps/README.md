# AZURE Esempio 07 - Logic Apps

Logic App completa che copia blob da storage source a destination e invoca una Function App per il logging delle operazioni.

⚠️ **Nota importante**: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attenzione prima di eseguire qualsiasi comando ⚠️

## Architettura

```
Storage Source → Logic App Trigger → Copy Blob → Storage Destination
                                   ↓
                              Function App Logger → Application Insights
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

- **Terraform**
  - `main.tf`: configurazione Terraform principale con deploy automatico del codice
  - `variables.tf`: variabili configurabili
  - `outputs.tf`: output utili post-deployment
  - `backend.tf`: configurazione backend remoto
  - `terraform.tfvars.example`: template per personalizzare le variabili
- **Function App** nella cartella `function/`
  - `function_app.py`: codice Python della Function App con 2 endpoint HTTP
  - `requirements.txt`: dipendenze Python (azure-functions)
  - `host.json`: configurazione runtime Azure Functions v2
- **Logic App** nella cartella `logicApp/`
  - `logic_app_workflow.json`: definizione completa del workflow JSON (riferimento)
  - `configure_logic_app.sh`: script helper per configurazione workflow
- **Utility**
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

⚠️ **Nota**: Il workflow della Logic App (trigger e actions) viene ora configurato direttamente via Terraform usando le risorse `azurerm_logic_app_trigger_custom` e `azurerm_logic_app_action_custom`.

## Utilizzo
- Prima di proseguire ricorsarsi di configurare la variabile d'ambiente che definisce la subscription (azurerm v4 richiede la subscription configurata esplicitamente), questo comando valorizza la variabile con l'ID della subscription attiva corrente:
  ```bash
  export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
  ```

- Deploy Infrastruttura
  ```bash
  chmod +x deploy.sh
  ./deploy.sh
  ```
  - Oppure manualmente:
  ```bash
  terraform init
  terraform plan
  terraform apply
  ```
- Test del Workflow (il workflow è già configurato da Terraform)

  ```bash
  SOURCE_STORAGE=$(terraform output -raw source_storage_name)
  echo $SOURCE_STORAGE
  echo "Test $(date)" > /tmp/test.txt

  az storage blob upload \
    --account-name $SOURCE_STORAGE \
    --container-name source \
    --name test.txt  --overwrite \
    --file /tmp/test.txt 

  # Attendi 1 minuto, poi verifica destination
  az storage blob list \
    --account-name $(terraform output -raw destination_storage_name) \
    --container-name destination \
    --output table
    
  ```
  Nota: It is recommended to provide `--connection-string`, `--account-key` or `--sas-token` in your command as credentials. You also can add `--auth-mode login` in your command to use Azure Active Directory (Azure AD) for authorization if your login account is assigned required RBAC roles.
- Test Function App
  ```bash
  FUNCTION_URL=$(terraform output -raw function_app_url)

  # Test logger
  curl -X POST "${FUNCTION_URL}/api/logger" \
    -H "Content-Type: application/json" \
    -d '{"blobName":"test.txt","sourceContainer":"source","destinationContainer":"destination","operationTime":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

  # Health check
  curl "${FUNCTION_URL}/api/health"
  ```
- Cleanup

  ```bash
  terraform destroy -auto-approve
  rm -f function.zip tfplan
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



# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella massima misura possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


Alcuni contenuti e porzioni di codice presenti in questo repository sono stati realizzati anche grazie al supporto di strumenti di intelligenza artificiale, il cui contributo ha permesso di arricchire e velocizzare la produzione del materiale. Ogni informazione e frammento di codice è stato comunque attentamente verificato e validato, con l'obiettivo di garantire la massima qualità e affidabilità dei contenuti offerti. 


Per ulteriori dettagli, approfondimenti o richieste di chiarimento, si invita a consultare il sito [AlNao.it](https://www.alnao.it/).


## License
Made with ❤️ by <a href="https://www.alnao.it">AlNao</a>
&bull; 
Public projects 
<a href="https://www.gnu.org/licenses/gpl-3.0"  valign="middle"> <img src="https://img.shields.io/badge/License-GPL%20v3-blue?style=plastic" alt="GPL v3" valign="middle" /></a>
*Free Software!*


Il software è distribuito secondo i termini della GNU General Public License v3.0. L'uso, la modifica e la ridistribuzione sono consentiti, a condizione che ogni copia o lavoro derivato sia rilasciato con la stessa licenza. Il contenuto è fornito "così com'è", senza alcuna garanzia, esplicita o implicita.


The software is distributed under the terms of the GNU General Public License v3.0. Use, modification, and redistribution are permitted, provided that any copy or derivative work is released under the same license. The content is provided "as is", without any warranty, express or implied.
