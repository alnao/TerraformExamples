# Azure-Esempio01-Storage
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

Questo esempio crea un **Azure Storage Account** con container blob, equivalente funzionale ad un bucket S3 di AWS. Include configurazioni avanzate per sicurezza, versioning, soft delete e lifecycle management.
I componenti creati da questo esempio sono:
- Resource Group: Gruppo di risorse per organizzare le risorse Azure
- Storage Account: Account di storage Azure configurabile con diversi tier e tipi di replica
- Storage Container(s): Container blob per archiviare i file (equivalenti ai bucket S3)
- Lifecycle Management Policy: Policy opzionale per gestire il ciclo di vita dei dati
- Configurazioni di sicurezza: TLS minimo, accesso pubblico controllato, soft delete

Nota: lo stato remoto degli esempi viene salvato nello storage-container `alnaoterraformstorage`, modificare il file `backend.tf` per personalizzare questa configurazione.

**Prerequisiti**:
1. **Azure CLI** installato e configurato:
   ```bash
   # Installazione Azure CLI (Ubuntu/Debian)
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   # Login ad Azure
   az login
   # Verifica subscription attiva
   az account show
   ```
2. **Terraform** installato (versione >= 1.0)
3. **Account Azure** attivo con i permessi necessari per creare:
   - Resource Groups
   - Storage Accounts
   - Storage Containers

Le **Variabili principali** del template sono
- `storage_account_name` : Nome univoco dello storage account (3-24 caratteri, solo minuscole e numeri)
- `resource_group_name` : Nome del resource group
- `location` : Regione Azure (default "West Europe")
- `account_tier` : Tier dello storage (Standard/Premium)
- `replication_type` : Tipo di replica (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)
- `containers` : Lista dei container da creare
- `enable_versioning` : Abilita versioning dei blob
- `enable_soft_delete` : Abilita soft delete

L'esempio espone diversi **output** utili per integrazioni:
- Informazioni base: nome, ID, location del storage account
- Endpoint: URL per accesso blob, web, Data Lake
- Chiavi di accesso: connection string e access key (marcate come sensitive)
- Container: nomi e URL dei container creati
- Configurazioni: tier, replica, sicurezza


⚠️ **Attenzione ai costi**: Azure Storage ha costi basati su:
- Quantità di dati archiviati
- Numero di operazioni (lettura/scrittura)
- Trasferimento dati in uscita
- Tipo di replica configurato
- Tier di accesso (Hot, Cool, Archive)
Monitora sempre i costi nel Azure Portal.


## Comandi principali
1. Inizializzazione
    ```bash
    cd AZURE-Esempio01-Storage
    terraform init
    ```
2. Configurazione delle variabili (facoltativo)
    Crea un file `terraform.tfvars` per personalizzare la configurazione:

    ```hcl
    # Configurazione base
    storage_account_name = "mystorageaccount123"  # Deve essere univoco globalmente
    resource_group_name  = "rg-my-storage"
    location            = "West Europe"

    # Configurazione storage
    account_tier      = "Standard"
    replication_type  = "LRS"  # LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS

    # Container da creare
    containers = [
    {
        name        = "documents"
        access_type = "private"
    },
    {
        name        = "public-files"
        access_type = "blob"
    }
    ]

    # Configurazioni di sicurezza
    allow_public_access     = false
    public_network_access   = true
    min_tls_version        = "TLS1_2"

    # Versioning e backup
    enable_versioning           = true
    enable_soft_delete          = true
    soft_delete_retention_days  = 30

    # Lifecycle management (opzionale)
    enable_lifecycle_policy        = true
    lifecycle_cool_after_days     = 30
    lifecycle_archive_after_days  = 90
    lifecycle_delete_after_days   = 365

    # Tags personalizzati
    tags = {
    Environment = "production"
    Project     = "my-project"
    Owner       = "team-name"
    CostCenter  = "IT-001"
    }
    ```
3. Pianificazione
    ```bash
    terraform plan
    ```
4. Applicazione
    ```bash
    terraform apply
    ```
5. Distruzione (quando necessario)
    ```bash
    terraform destroy
    ```

## Integrazione con applicazioni
- .NET
    ```csharp
    var connectionString = "DefaultEndpointsProtocol=https;AccountName=...";
    var blobServiceClient = new BlobServiceClient(connectionString);
    ```
- Python
    ```python
    from azure.storage.blob import BlobServiceClient
    connection_string = "DefaultEndpointsProtocol=https;AccountName=..."
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)
    ```
- Azure CLI
    ```bash

    # Create & upload file
    echo "Ciao" > /tmp/testfileXazure.txt
    az storage blob upload --account-name alnaoterraformesempio01 --container-name documents --name testfile.txt --file /tmp/testfileXazure.txt

    # Download file
    az storage blob download --account-name alnaoterraformesempio01 --container-name documents --name testfile.txt --file /tmp/testfileFromAzure.txt
    cat /tmp/testfileFromAzure.txt 

    # URL pubblici (solo per container "public-assets")
    # Ottieni la URL base
    terraform output storage_account_primary_blob_endpoint
    AZ_URL=$(terraform output storage_account_primary_blob_endpoint)
    # URL formato: https://alnaoterraformesempio01.blob.core.windows.net/public-assets/nomefile.jpg
    # curl "$AZ_URL/documents/testfile.txt"
    curl https://alnaoterraformesempio01.blob.core.windows.net/documents/testfile.txt
    # potrebbe non andare con errore "Public access is not permitted on this storage account" per mancanza di permessi
    ```
- Esempi di utilizzo degli output
    ```bash
    # Visualizza tutti gli output (esclusi i sensitive)
    terraform output

    # Visualizza un output specifico
    terraform output storage_account_name

    # Visualizza output sensitive
    terraform output -raw storage_account_primary_access_key
    ```

## Confronto con AWS S3

| Caratteristica | AWS S3 | Azure Blob Storage |
|----------------|--------|-------------------|
| Container | Bucket | Storage Container |
| Replica cross-region | Cross-Region Replication | GRS/RAGRS |
| Lifecycle | Lifecycle Configuration | Lifecycle Management Policy |
| Versioning | Object Versioning | Blob Versioning |
| Soft Delete | - | Soft Delete |
| Storage Classes | Standard, IA, Glacier | Hot, Cool, Archive |

## Risorse utili

- [Azure Storage Documentation](https://docs.microsoft.com/azure/storage/)
- [Azure CLI Storage Commands](https://docs.microsoft.com/cli/azure/storage)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Azure Storage Pricing](https://azure.microsoft.com/pricing/details/storage/)


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



