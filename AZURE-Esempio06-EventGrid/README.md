# AZURE Esempio 06 - Event Grid

Esempio Azure Function triggerata da Event Grid quando viene caricato un blob in Storage Account.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**
- Resource Group
- Storage Account (sorgente)
- Storage Account (function)
- Function App
    - Il codice della Function è in `function_code/` (trigger su blob `sourcedata/{name}`)
    - Terraform crea automaticamente lo zip e lo pubblica via `WEBSITE_RUN_FROM_PACKAGE`
    - Per modificare il trigger su un container diverso, aggiorna `function_code/BlobEventProcessor/function.json` (chiave `path`) in coerenza con `var.source_container_name`
- Event Grid System Topic
- Event Grid Subscription
- Application Insights
- Metric Alerts (opzionale)

**Prerequisiti**
- Azure CLI installato e autenticato
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva



## Comandi
- Oppure inizializzazione del terraform
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```
- Deploy della sola funzione
    ```bash
    terraform destroy -target=azurerm_linux_function_app.main -target=azurerm_role_assignment.storage_blob_data_reader -target=time_sleep.wait_for_function -auto-approve

    az functionapp config appsettings set --name func-eventgrid-06 --resource-group alnao-terraform-esempio06-eventgrid --settings WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_URL="" 
    sleep 5
    terraform apply -auto-approve
    ```
- Test
    ```bash
    echo "Test Event Grid Trigger $(date)" > /tmp/test-eventgrid.txt && az storage blob upload -f /tmp/test-eventgrid.txt -c sourcedata -n test-eventgrid.txt --account-name stsource06 --overwrite
    ```
- Rimozione di tutte le risorse terraform
  ```bash
  terraform destroy
  ```


## Riferimenti
- [Event Grid Documentation](https://docs.microsoft.com/azure/event-grid/)
- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Python Developer Guide](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)
- [Functions Pricing](https://azure.microsoft.com/pricing/details/functions/)
- [Best Practices](https://docs.microsoft.com/azure/azure-functions/functions-best-practices)

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
