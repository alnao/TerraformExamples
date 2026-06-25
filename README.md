# Terraform Examples
  <p align="center">
   <img src="https://img.shields.io/badge/Terraform-623CE4?logo=terraform&logoColor=white"   height=32/>
   <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white"    height=32/>
   <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white"   height=32/>
  </p>

**Terraform** è uno strumento open source per l'Infrastructure as Code (IaC) che consente di definire, gestire e versionare infrastrutture cloud tramite file di configurazione testuali. Supporta numerosi provider, tra cui AWS, Azure, Google Cloud e molti altri.

Questo repository raccoglie una collezione di esempi pratici per l'utilizzo di Terraform su diversi provider cloud, principalmente AWS e Azure. Ogni cartella contiene un esempio autonomo, pensato per mostrare best practice, modularità e parametrizzazione.
Ogni esempio è contenuto in una cartella specifica e include:
  - File di configurazione Terraform (`main.tf`, `variables.tf`, `outputs.tf`, ecc. )
  - Un file README.md con istruzioni specifiche
  - Eventuali moduli riutilizzabili


**Prerequisiti** necessari al funzionamento degli esempi:
- [Terraform](https://www.terraform.io/downloads.html) installato, consigliato anche Docker
- Account cloud attivo e funzionante (AWS, Azure, ecc.), 
   - ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati ⚠️
- Per ogni cloud attivo, è necessario avere le credenziali configurate:
   - Per **AWS** devono essere configurate le credenziali tramite il comando `aws configure` della AWS CLI
      - Nota: lo stato remoto di tutti gli esempi vengono salvati nel bucket `alnao-dev-terraform`, modificare il file `backend.ft` per personalizzare questa configurazione.
   - Per **Azure** devono essere configurate le credenziali tramite il comando `az login` della Azure CLI
      - In ambiente di sviluppo/laboratorio si può configurare la subscription di default con la procedura:
         - Eseguire la login da cli `az login`
         - Recuperare la lista delle subscription `az account list --output table`
         - Configurare la subscription di default con il nome o con l'id, per esempio:
            ```
            `az account set --subscription "xxxx-xxxx-xxxx-xxxx-xxxx"`
            ```
         - Oppure creare file `terraform.tfvars` con il contenuto
            ```
            subscription_id = "xxxx-xxxx-xxxx-xxxx-xxxx"
            ```
         - La *nuova* versione del *provider terraform azure* necessita **sempre** la subscription configurata: in `azurerm-v4' bisogna specificare esplicitamente la subscription oppure tramite la variabile d'ambiente ARM_SUBSCRIPTION_ID.
            ```bash
            export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
            ```
      - Per alcuni termplate (Esempio08) necessita pacchetti specifici:
         ```sudo npm install -g azure-functions-core-tools@4 --unsafe-perm true```
      - Nota: lo stato remoto degli esempi viene salvato nello storage-container `alnaoterraformstorage`, modificare il file `backend.tf` per personalizzare questa configurazione.
         - In caso di blocco (per interruzione improvvisa di precedenti comandi `apply`) con errore `Error: Error acquiring the state lock` si deve procedere manualmente allo sblocco con il comando:
            ```
            az storage blob lease break \
            --account-name alnaoterraformstorage \
            --container-name alnao-terraform-blob-container \
            --blob-name esempio04frontdoor.tfstate
            ```
            oppure da console web selezionando il file `esempioXX.tfstate` e usando la funzionalità "Break lease" (se disponibile)
        
      

## Elenco degli esempi

⚠️ **Nota importante**: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati ⚠️

**Note sullo stato remoto:**
- **AWS**: lo stato remoto viene salvato nel bucket `alnao-dev-terraform`, modificare il file `backend.tf` per personalizzare.
- **Azure**: lo stato remoto viene salvato nello storage-container `alnaoterraformstorage` del `alnao-terraform-resource-group`, modificare il file `backend.tf` per personalizzare. In tutti gli esempi Azure, i Resource Group creati hanno nome `alnao-terraform-esempioXX`.

| Cloud | Esempio | Dettagli |
|:---:|---|---|
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [BucketS3](AWS-Esempio01-BucketS3/) | Crea un bucket S3 su region di Francoforte (eu-central-1), tagging e alcune opzioni configurabili <br> **Servizi**: S3 <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [IstanzaEC2](AWS-Esempio02-IstanzaEC2/) | Crea un'istanza EC2 con Amazon Linux 2023, Security Group configurabile per SSH/HTTP/HTTPS, supporto chiavi SSH, volumi EBS cifrati, user data per inizializzazione e Elastic IP opzionale <br> **Servizi**: EC2, VPC, EBS, IAM <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [IstanzaEC2-module](AWS-Esempio02-IstanzaEC2-module/) | Crea una istanza EC2 usando il modulo ufficiale disponibile su `registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws` <br> **Servizi**: EC2 (modulo ufficiale Terraform) <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [WebSiteS3](AWS-Esempio03-WebSiteS3/) | Hosting di sito web statico su S3 con configurazione automatica di accesso pubblico, CORS, versioning, custom error pages e upload automatico di file HTML <br> **Servizi**: S3 (Static Website Hosting) <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [CloudFront](AWS-Esempio04-CloudFront/) | Distribuzione CloudFront CDN con origine S3, HTTPS nativo, Origin Access Control (OAC), compressione automatica, custom error responses, WAF opzionale e supporto domini personalizzati con certificati ACM <br> **Servizi**: CloudFront, S3, ACM, WAF <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [Lambda](AWS-Esempio05-Lambda/) | Lambda function Python 3.11 che lista oggetti in bucket S3 con parametro path, Function URL per invocazione HTTP diretta, CORS configurato, supporto VPC, Dead Letter Queue opzionale e CloudWatch Alarms <br> **Servizi**: Lambda, S3, IAM, CloudWatch <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [EventBridge](AWS-Esempio06-EventBridge/) | EventBridge Rule che triggera Lambda quando file viene caricato in S3, pattern matching, input transformer, retry policy configurabile, Dead Letter Queue e CloudWatch Alarms <br> **Servizi**: EventBridge, Lambda, S3, SQS, CloudWatch <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [StepFunction](AWS-Esempio07-StepFunction/) | Step Function State Machine che copia file da bucket A a bucket B e invoca Lambda per logging, trigger automatico via EventBridge su S3 upload, gestione errori con catch e retry, X-Ray tracing opzionale <br> **Servizi**: Step Functions, Lambda, S3, EventBridge, CloudWatch <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [ApiGateway](AWS-Esempio08-ApiGateway/) | API Gateway REST con due metodi - GET /files (lista file da S3) e POST /calculate (calcola ipotenusa dati cateti), integrazione Lambda proxy, CORS, Usage Plan con rate limiting, API Key opzionale <br> **Servizi**: API Gateway, Lambda, S3, CloudWatch <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [DynamoDB](AWS-Esempio09-DynamoDB/) | Tabella DynamoDB NoSQL con billing flessibile, Global/Local Secondary Indexes, DynamoDB Streams, Point-in-Time Recovery, autoscaling, TTL e Global Tables. Include Lambda trigger su S3 upload per salvare dati in DynamoDB <br> **Servizi**: DynamoDB, Lambda, S3, IAM, CloudWatch <br> Ultimo aggiornamento: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [RDS](AWS-Esempio10-RDS/) | Cluster RDS Aurora MySQL 8.0 (db.t3.medium) con accesso pubblico configurabile, Security Group, backup automatici, CloudWatch Logs, Parameter Groups, Enhanced Monitoring e Performance Insights opzionali <br> **Servizi**: RDS Aurora, VPC, CloudWatch <br> Ultimo aggiornamento con test completo: Aprile 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [Lambda Appl](AWS-Esempio11-LambdaApplicationS3Utils/) | Applicazione serverless completa per gestisce l'intero ciclo di vita dei file da carico, import su db, export e reportistica. <br> **Servizi**: Lambda, S3, DynamoDB, RDS, API Gateway, EventBridge, Secrets Manager, SSM, CloudWatch, IAM <br> Ultimo aggiornamento con test completo: Giugno 2026 |
| <img src="https://img.shields.io/badge/AWS-%23FF9900?logo=AmazonAWS&logoColor=white" height=24/> | 📁 [Glue job](AWS-Esempio12-GlueJob) | Applicazione serverless che carica un excel, esegue un Job-ETL nel csv eseguendo un filtro sui dati<br> **Servizi**: Glue job, Step function, Lambda, S3, EventBridge <br> Ultimo aggiornamento con test completo: Giugno 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [Storage](AZURE-Esempio01-Storage/) | Crea un Azure Storage Account con container blob (equivalente ad AWS S3), con configurazioni avanzate per sicurezza, versioning, soft delete, lifecycle management e replica geografica <br> **Servizi**: Storage Account, Blob Container <br> Ultimo aggiornamento: Febbraio 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [IstanzeVM](AZURE-Esempio02-IstanzeVM/) | Crea una Virtual Machine Linux (Ubuntu 22.04) con Virtual Network, Public IP opzionale, Network Security Group, autenticazione SSH o password, boot diagnostics, managed disk opzionale e cloud-init <br> **Servizi**: Virtual Machine, VNet, NSG, Public IP <br> Ultimo aggiornamento: Febbraio 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [WebsiteBlob](AZURE-Esempio03-WebsiteBlob/) | Hosting di sito web statico su Blob Storage con HTTPS nativo, CORS configurato, versioning, soft delete, Azure CDN opzionale per performance e supporto domini personalizzati con certificati gestiti <br> **Servizi**: Blob Storage, CDN <br> Ultimo aggiornamento: Febbraio 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [FrontDoor](AZURE-Esempio04-FrontDoor/) | Distribuzione Azure Front Door (Standard/Premium) con origine Blob Storage, HTTPS automatico, Anycast routing, Rules Engine per caching, WAF integrato opzionale, health probes, DDoS protection e certificati SSL gestiti <br> **Servizi**: Front Door, Blob Storage, WAF <br> Ultimo aggiornamento: Febbraio 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [Functions](AZURE-Esempio05-Functions/) | Azure Function Python 3.11 che lista blob in Storage Container con parametro path, HTTP Trigger per invocazione REST, Managed Identity per accesso storage, Application Insights per monitoring <br> **Servizi**: Functions, Storage Account, Application Insights <br> Ultimo aggiornamento: Febbraio 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [EventGrid](AZURE-Esempio06-EventGrid/) | Event Grid System Topic su Storage Account che triggera Function quando blob viene creato, Event Grid Subscription con filtri avanzati, batching configurabile, retry policy e Dead Letter destination opzionale <br> **Servizi**: Event Grid, Functions, Storage Account, Application Insights <br> Ultimo aggiornamento: Marzo 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [LogicApps](AZURE-Esempio07-LogicApps/) | Logic App Workflow che copia blob da storage A a B e invoca Function per logging, trigger automatico quando blob viene aggiunto, API Connection per Blob Storage, Managed Identity per accesso sicuro <br> **Servizi**: Logic Apps, Functions, Blob Storage, Managed Identity <br> Ultimo aggiornamento: Marzo 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [APIManagement](AZURE-Esempio08-APIManagement/) | API Management (Consumption SKU) con due API - GET /api/files (lista blob) e POST /api/calculate (calcola ipotenusa), backend Azure Functions, policies personalizzate, Application Insights logger <br> **Servizi**: API Management, Functions, Application Insights <br> ⚠️ *In fase di revisione* — Ultimo aggiornamento: Febbraio 2026 |
| <img src="https://img.shields.io/badge/Azure-0078D4?logo=microsoftazure&logoColor=white" height=24/> | 📁 [CosmosMongo](AZURE-Esempio09-CosmosMongo/) | Database CosmosDB con API MongoDB, consistency levels configurabili, geo-replication multi-region, autoscaling, modalità serverless, backup periodic/continuous, free tier e Analytical Storage per Synapse Link <br> **Servizi**: CosmosDB (MongoDB API) <br> ⚠️ *In fase di revisione* — Ultimo aggiornamento: Gennaio 2026 |
| <img src="https://img.shields.io/badge/DevOps-0A0A0A?logo=devdotto&logoColor=white" height=24/> | 📁 [Pipeline](DEVOPS-Esempio01-Pipeline/) | Pipeline CI/CD di esempio <br> **Servizi**: Pipeline <br> ⚠️ *In fase di revisione* — Ultimo aggiornamento: Ottobre 2025 |
| <img src="https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white" height=24/> | 📁 [Nginx](DOCKER-Esempio01-Nginx/) | Crea un container Docker *locale* con server Nginx che serve una pagina HTML personalizzata con Bootstrap 5, mappando la porta 8001 e montando una directory locale per i file web <br> **Servizi**: Docker, Nginx <br> Ultimo aggiornamento: Ottobre 2025 |
| <img src="https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white" height=24/> | 📁 [Nginx](KUBERNETES-Esempio01-Nginx/) | Crea un deployment Kubernetes *locale* con server Nginx che serve una pagina HTML personalizzata con Bootstrap 5, usando ConfigMap per i file web, Service con NodePort e supporto per scaling automatico <br> **Servizi**: Kubernetes, Nginx, ConfigMap, Service <br> Ultimo aggiornamento: Ottobre 2025 |


## Comandi principali
1. Inizializza la cartella di lavoro:
   ```bash
   terraform init
   ```
2. Visualizza il piano di esecuzione:
   ```bash
   terraform plan
   ```
3. Applica la configurazione:
   ```bash
   terraform apply
   ```
4. Distruggi le risorse:
   ```bash
   terraform destroy
   ```


## Risorse utili
- [AlNao Debian HandBook](https://github.com/alnao/alnao/blob/main/DEBIAN.md) per una guida di installazione di Docker e Terraform in sistemi GNU Linux Debian
- [Documentazione Terraform](https://www.terraform.io/docs)
- [Provider AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Provider Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)


# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella massima misura possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


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



