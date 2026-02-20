# Terraform Examples
  <p align="center">
   <img src="https://img.shields.io/badge/Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=white"   height=60/>
   <img src="https://img.shields.io/badge/AWS-%23FF9900?style=for-the-badge&logo=AmazonAWS&logoColor=white"    height=60/>
   <img src="https://img.shields.io/badge/Azure-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white"   height=60/>
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
   - ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️
- Per ogni cloud attivo, è necessario avere le credenziali configurate:
   - Per AWS devono essere configurate le credenziali tramite il comando `aws configure` della AWS CLI
      - Nota: lo stato remoto di tutti gli esempi vengono salvati nel bucket `terraform-aws-alnao`, modificare il file `backend.ft` per personalizzare questa configurazione.
   - Per Azure devono essere configurate le credenziali tramite il comando `az login` della Azure CLI
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
      

## Esempi AWS (Amazon Web Services)
Nota: lo stato remoto di tutti gli esempi vengono salvati nel bucket `terraform-aws-alnao`, modificare il file `backend.ft` per personalizzare questa configurazione.

- **AWS-Esempio01-BucketS3**: crea un bucket S3 parametrico su AWS, con region di default Francoforte (eu-central-1), salvataggio dello stato remoto su S3, tagging e alcune opzioni configurabili
- **AWS-Esempio02-IstanzaEC2**: crea un'istanza EC2 con Amazon Linux 2023, Security Group configurabile per SSH/HTTP/HTTPS, supporto chiavi SSH, volumi EBS cifrati, user data per inizializzazione e Elastic IP opzionale
- **AWS-Esempio02-IstanzaEC2-module**: crea una istanza EC2 usando il modulo ufficiale disponibile su `registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws` 
- **AWS-Esempio03-WebSiteS3**: hosting di sito web statico su S3 con configurazione automatica di accesso pubblico, CORS, versioning, custom error pages e upload automatico di file HTML
- **AWS-Esempio04-CloudFront**: distribuzione CloudFront CDN con origine S3, HTTPS nativo, Origin Access Control (OAC), compressione automatica, custom error responses, WAF opzionale e supporto domini personalizzati con certificati ACM
- **AWS-Esempio05-Lambda**: Lambda function Python 3.11 che lista oggetti in bucket S3 con parametro path, Function URL per invocazione HTTP diretta, IAM role con accesso S3, CloudWatch Logs, CORS configurato, supporto VPC, Dead Letter Queue opzionale e CloudWatch Alarms per monitoring
- **AWS-Esempio06-EventBridge**: EventBridge Rule che triggera Lambda quando file viene caricato in S3, pattern matching per filtrare eventi specifici, input transformer per personalizzare payload, retry policy configurabile, Dead Letter Queue per eventi falliti e CloudWatch Alarms per monitoring
- **AWS-Esempio07-StepFunction**: Step Function State Machine che copia file da bucket A a bucket B e invoca Lambda per logging, trigger automatico via EventBridge su S3 upload, gestione errori con catch e retry, CloudWatch Logs con X-Ray tracing opzionale e workflow orchestration completa
- **AWS-Esempio08-ApiGateway**: API Gateway REST con due metodi - GET /files (lista file da S3) e POST /calculate (calcola ipotenusa dati cateti), integrazione Lambda proxy, CORS configurato, Usage Plan con rate limiting, API Key opzionale, CloudWatch Logs e deployment automatico con stage
- **AWS-Esempio09-DynamoDB**: tabella DynamoDB NoSQL con billing flessibile (On-Demand/Provisioned), Global/Local Secondary Indexes, DynamoDB Streams, Point-in-Time Recovery, autoscaling, TTL e replica multi-region con Global Tables. 
   - in aggiunta è presente un template per creare una lambda eseguita al caricamento di un file in un bucket S3 e i dati vengono salvati nella tabella Dynamo
- **AWS-Esempio10-RDS**: *progetto in fase di revisione,* cluster RDS Aurora MySQL 8.0 più piccolo disponibile (db.t3.small) con accesso pubblico configurabile, Security Group con porta 3306, backup automatici (7 giorni), CloudWatch Logs (audit, error, general, slowquery), Parameter Groups personalizzati, Enhanced Monitoring opzionale, Performance Insights opzionale e CloudWatch Alarms per CPU/connessioni/memoria
- **AWS-Esempio11-LambdaApplicationS3Utils**: *progetto in fase di revisione,* applicazione serverless completa con 8 Lambda Functions (presigned URL, extract ZIP, Excel to CSV, upload to RDS, SFTP send, S3 scan, list/search files), S3 Bucket con public access policy, 2 DynamoDB Tables (logs e scan), RDS Aurora MySQL, API Gateway REST con 7 endpoint, EventBridge per orchestrazione e scheduling (scansione S3 giornaliera), Secrets Manager per credenziali RDS, SSM Parameter Store per chiave SFTP RSA, CloudWatch con alarms e logging, IAM con policy granulari e tagging completo. L'applicazione gestisce l'intero ciclo di vita dei file: upload tramite presigned URL, elaborazione automatica (ZIP extraction, Excel conversion), caricamento dati su database, invio via SFTP e API per ricerca/elenco file
- **AWS-Esempio12-Annotazioni**: *progetto in fase di revisione, chissà se mai lo finirò* 
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️


## Esempi Azure (Microsoft Azure)
In tutti gli esempi, i Resource Group creati hanno nome `alnao-terraform-esempioXX`. Lo stato remoto degli esempi viene salvato nello storage-container `alnaoterraformstorage` del `alnao-terraform-resource-group`, modificare i file `backend.tf` dei vari esempi per personalizzare questa configurazione.

- **AZURE-Esempio01-Storage**: crea un Azure Storage Account con container blob (equivalente ad AWS S3), con configurazioni avanzate per sicurezza, versioning, soft delete, lifecycle management e replica geografica
- **AZURE-Esempio02-IstanzeVM**: crea una Virtual Machine Linux (Ubuntu 22.04) con Virtual Network, Public IP opzionale, Network Security Group, autenticazione SSH o password, boot diagnostics, managed disk aggiuntivo opzionale e supporto cloud-init
- **AZURE-Esempio03-WebsiteBlob**: hosting di sito web statico su Blob Storage con HTTPS nativo, CORS configurato, versioning, soft delete, Azure CDN opzionale per performance e supporto domini personalizzati con certificati gestiti
- **AZURE-Esempio04-FrontDoor**: distribuzione Azure Front Door (Standard/Premium) con origine Blob Storage, HTTPS automatico, Anycast routing, Rules Engine per caching, WAF integrato opzionale con versione Premium SKU, health probes, DDoS protection e certificati SSL gestiti
- **AZURE-Esempio05-Functions**: Azure Function Python 3.11 che lista blob in Storage Container con parametro path, HTTP Trigger per invocazione REST, Managed Identity per accesso storage, Application Insights per monitoring, CORS configurato, supporto Consumption/Premium plan e Metric Alerts opzionali
- **AZURE-Esempio06-EventGrid**: Event Grid System Topic su Storage Account che triggera Function quando blob viene creato, Event Grid Subscription con filtri avanzati, batching configurabile, retry policy, Dead Letter destination opzionale e integrazione Application Insights per monitoring
- **AZURE-Esempio07-LogicApps**: *progetto in fase di revisione,* Logic App Workflow che copia blob da storage A a B e invoca Function per logging, trigger automatico quando blob viene aggiunto, API Connection per Blob Storage, Managed Identity per accesso sicuro, orchestrazione visuale e integrazione completa con servizi Azure
- **AZURE-Esempio08-APIManagement**: API Management (Consumption SKU) con due API - GET /api/files (lista blob) e POST /api/calculate (calcola ipotenusa), backend Azure Functions, API Operations con policies personalizzate, Application Insights logger, Named Values per configurazione e throttling/quota opzionali
- **AZURE-Esempio09-CosmosMongo**: database CosmosDB con API MongoDB, consistency levels configurabili (5 livelli), geo-replication multi-region, autoscaling, modalità serverless, backup periodic/continuous, free tier (400 RU/s gratuiti) e Analytical Storage per Synapse Link
- **AZURE-Esempio12-Annotazioni**: *progetto in fase di revisione, chissà se mai lo finirò* 
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

## Esempi DevOps & CI/CD
- **DEVOPS-Esempio01-Pipeline**: *progetto in fase di revisione*

## Esempi Container & Orchestrazione
- **DOCKER-Esempio01-Nginx**: crea un container Docker *locale* con server Nginx che serve una pagina HTML personalizzata con Bootstrap 5, mappando la porta 8001 e montando una directory locale per i file web
- **KUBERNETES-Esempio01-Nginx**: crea un deployment Kubernetes *locale* con server Nginx che serve una pagina HTML personalizzata con Bootstrap 5, usando ConfigMap per i file web, Service con NodePort e supporto per scaling automatico (richiede cluster Kubernetes locale come minikube o kind)


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



