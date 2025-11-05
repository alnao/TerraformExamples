# Azure Esempio 09 - CosmosDB con MongoDB API

Questo esempio mostra come creare un database Azure CosmosDB con API MongoDB usando Terraform.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**
- Resource Group: Gruppo di risorse dedicato
- Cosmos DB Mongo Cluster: Cluster Cosmos DB for MongoDB vCore (versione 5.0, Free Tier)
  - **Free tier** attivato di default con gratuiti i limiti di: 400 RU/s + 5GB gratuiti  
  - La creazione di database e collection MongoDB avviene tramite applicazione client (es. script Python), non via Terraform.
- Azure Key Vault: Per salvare in modo sicuro connection string, username e password
- Private Endpoint: (Opzionale) Accesso privato tramite VNet e Private DNS Zone esistenti
  - Presente un file separato di esempio per la creazione delle VNet e Private zone 
- Tag: Applicati a tutte le risorse
- Presenza di uno script python di prova `test.py`

**Prerequisiti**
- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva
- Python3 per lo script di prova


**Variabili principali**
- `subscription_id`: ID della subscription Azure
- `resource_group_name`: Nome del Resource Group
- `cosmosdb_account_name`: Nome univoco del cluster MongoDB
- `mongodb_username` / `mongodb_password`: Credenziali amministratore MongoDB
- `enable_public_network_access`: `"Enabled"` (default) o `"Disabled"`
- `enable_private_endpoint`: `false` (default, consigliato per test da locale)
- `enable_key_vault`: `true` (default)
- `key_vault_name`: Nome Key Vault (univoco globale)

**Output principali**
- `cosmosdb_mongo_cluster_name`: Nome del cluster MongoDB
- `cosmosdb_connection_strings`: Connection strings MongoDB (JSON, sensibile)
- `key_vault_uri`: URI del Key Vault
- `key_vault_secret_names`: Nomi dei secrets creati (connection string, username, password)
- `private_endpoint_id` / `private_endpoint_ip`: Info Private Endpoint (se abilitato)



## Comandi
- Inizializzazione
  ```bash
  terraform init
  terraform plan
  ```
- Apply/Deploy base con free tier attivato per default (400 RU/s gratuiti)
  ```bash
  terraform apply 
  ```
  - Deploy senza free tier 
    ```bash
    terraform apply -var="enable_free_tier=false"
    ```
 
  - Recuperare la connections string
    ```bash
    az keyvault secret show \
      --vault-name alnao-terraform-es9-key \
      --name cosmosdb-mongodb-connection-string \
      --query value -o tsv
    ```

  - Verifica dello stato del cluster
    ```
    az extension add --name cosmosdb-preview
    az cosmosdb mongocluster list \
      --resource-group alnao-terraform-esempio09-cosmosmongo
    ```

  - Aggiunta della regola di rete per *aprire* la porta di cosmos al solo indirizzo IP del chiamante
    ```
    MYIP=$(curl -s ifconfig.me)
    az cosmosdb mongocluster firewall rule create \
      --cluster-name alnao-terraform-esempio09-cosmosmongo \
      --resource-group alnao-terraform-esempio09-cosmosmongo \
      --rule-name AllowMyIP \
      --start-ip-address $MYIP \
      --end-ip-address $MYIP
    ```
    - Eventuale regola di rete per aprire il cosmos a tutti gli IP (*sconsiagliata*)
      ```
      az cosmosdb mongocluster firewall rule create \
        --cluster-name alnao-terraform-esempio09-cosmosmongo \
        --resource-group alnao-terraform-esempio09-cosmosmongo \
        --rule-name AllowAll \
        --start-ip-address 0.0.0.0 \
        --end-ip-address 255.255.255.255
      ```
  - Esecuzione script di esempio
    ```
    python3 test.py
    ```
  - Eventuali comandi da eseguire nella console MongoDb, collegandosi da remoto con la "mongo cli" oppure in console web con "Quick start" > "Mongo shell"
    ```
    show databases
    use mydatabase
    show collections
    db.annotazioni.find()
    ```
- Distruzione (quando necessario)
    ```bash
    terraform destroy
    ```
  - Comandi per la verifica e rimozione parziale
      ```bash
      terraform state list
      terraform state rm azurerm_cosmosdb_account.main  # Se esiste
      terraform apply
      ```
- Connessione al database
  - Connection string
    ```bash
    # Ottieni connection string
    terraform output -raw cosmosdb_connection_strings[0]
    # Formato: mongodb://<name>:<key>@<name>.mongo.cosmos.azure.com:10255/?ssl=true
    ```
  - Con mongosh
    ```bash
    mongosh "mongodb+srv://<credentials>@alnao-terraform-esempio09-cosmosmongo.mongocluster.cosmos.azure.com/?authMechanism=SCRAM-SHA-256&retrywrites=false&maxIdleTimeMS=120000&appName=CosmosExplorerTerminal"
    ```
  - Python
    ```python
    from pymongo import MongoClient
    connection_string = "mongodb://..."
    client = MongoClient(connection_string)
    db = client['mydatabase']
    collection = db['annotazioni']

    # Test inserimento
    print ("Inserimento di una annotazione di prova...")
    collection.insert_one({"test": "annotazione di prova"})

    print ( "Collezione 'annotazioni':")
    print(collection.find_one())
    ```

## Costi esempio
- **Free Tier**: 3.000 RU/s e 32 GB inclusi
- **Provisioned**: Vedi [calcolatore prezzi Cosmos DB](https://azure.microsoft.com/en-us/pricing/details/cosmos-db/)
  - Provisioned (400 RU/s)
    - Throughput: 400 RU/s × €0.008/100 × 730h = €23.36
    - Storage 10 GB: 10 × €0.23 = €2.30
    - **Totale**: ~€25.66/mese
  - Serverless (10M RU/mese)
    - RU: 10 × €0.25 = €2.50
    - Storage 5 GB: 5 × €0.23 = €1.15
    - **Totale**: ~€3.65/mese
  - Multi-region (2 regioni, 400 RU/s)
    - Throughput: €23.36 × 2 = €46.72
    - Storage: €2.30 × 2 = €4.60
    - **Totale**: ~€51.32/mese


## Differenze con DynamoDB

| Feature | CosmosDB Mongo | DynamoDB |
|---------|----------------|----------|
| API | MongoDB | Proprietaria |
| Consistency | 5 livelli | 2 livelli |
| Multi-region | ✅ Nativo | ✅ Global Tables |
| Serverless | ✅ | ✅ |
| Free tier | 400 RU/s + 5GB | 25 GB + 25 RCU/WCU |
| Geo-distribution | Active-Active | Active-Active |
| Max item size | 2 MB | 400 KB |


## Riferimenti

- [CosmosDB Documentation](https://docs.microsoft.com/azure/cosmos-db/)
- [MongoDB API Docs](https://docs.microsoft.com/azure/cosmos-db/mongodb/introduction)
- [Pricing Calculator](https://azure.microsoft.com/pricing/details/cosmos-db/)
- [Capacity Planner](https://cosmos.azure.com/capacitycalculator/)
- [Terraform AzureRM Provider - azurerm_mongo_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mongo_cluster)
- [Azure Cosmos DB for MongoDB vCore](https://learn.microsoft.com/azure/cosmos-db/mongodb/vcore/)
- [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview)


# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella misura massima possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


Alcuni contenuti e porzioni di codice presenti in questo repository sono stati realizzati anche grazie al supporto di strumenti di intelligenza artificiale, il cui contributo ha permesso di arricchire e velocizzare la produzione del materiale. Ogni informazione e frammento di codice è stato comunque attentamente verificato e validato, con l’obiettivo di garantire la massima qualità e affidabilità dei contenuti offerti. 


Per ulteriori dettagli, approfondimenti o richieste di chiarimento, si invita a consultare il sito [AlNao.it](https://www.alnao.it/).


## License
Made with ❤️ by <a href="https://www.alnao.it">AlNao</a>
&bull; 
Public projects 
<a href="https://www.gnu.org/licenses/gpl-3.0"  valign="middle"> <img src="https://img.shields.io/badge/License-GPL%20v3-blue?style=plastic" alt="GPL v3" valign="middle" /></a>
*Free Software!*


Il software è distribuito secondo i termini della GNU General Public License v3.0. L'uso, la modifica e la ridistribuzione sono consentiti, a condizione che ogni copia o lavoro derivato sia rilasciato con la stessa licenza. Il contenuto è fornito "così com'è", senza alcuna garanzia, esplicita o implicita.


The software is distributed under the terms of the GNU General Public License v3.0. Use, modification, and redistribution are permitted, provided that any copy or derivative work is released under the same license. The content is provided "as is", without any warranty, express or implied.



