# Azure Esempio 03 - Sito Web Statico su Blob Storage

Questo esempio mostra come creare e hostare un sito web statico su Azure Blob Storage usando Terraform.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**:
- Resource Group: Gruppo di risorse per organizzare le risorse
- Storage Account: Account storage configurato per static website hosting
- Static Website: Configurazione per hosting di siti web statici
- Blob Storage: Container $web per i file del sito
- CORS Configuration: Configurazione CORS per accesso cross-origin
- Versioning: (Opzionale) Versioning dei blob
- CDN Profile: (Opzionale) Azure CDN per HTTPS e performance
- CDN Endpoint: (Opzionale) Endpoint CDN con compressione
- Custom Domain: (Opzionale) Dominio personalizzato

Nota: lo stato remoto degli esempi viene salvato nello storage-container `alnaoterraformstorage`, modificare il file `backend.tf` per personalizzare questa configurazione.

**Prerequisiti**
- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva

**Variabili principali**
- `location`: Regione Azure (default: West Europe)
- `storage_account_name`: Nome dello Storage Account (deve essere univoco globalmente, 3-24 caratteri, solo minuscole e numeri)
- `index_document`: Document index (default: index.html)
- `error_document`: Document error (default: error.html)
- `enable_cdn`: Abilita Azure CDN (default: false)
- `enable_versioning`: Abilita versioning (default: true)

**Costi stimati** (West Europe)
⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️
- Storage Account (Hot tier): ~€0.018/GB/mese
- Transazioni (letture): ~€0.004 per 10.000 operazioni
- Bandwidth (egress): €0.087/GB (primi 10 TB)
- CDN Standard Microsoft (opzionale): ~€0.081/GB transfer + €8.00/mese
- Esempio per sito da 100MB con 10.000 visite/mese (1MB per visita):
  - Storage: ~€0.002/mese
  - Transazioni: ~€0.004/mese
  - Bandwidth: ~€8.70/mese
  - CDN (se abilitato): ~€16.00/mese
  - **Totale**: ~€8.70/mese (senza CDN) o ~€24.70/mese (con CDN)


**Output**
- `resource_group_name`: Nome del Resource Group
- `storage_account_name`: Nome dello Storage Account
- `primary_web_endpoint`: Endpoint primario del sito web
- `primary_web_host`: Host primario
- `website_url`: URL completo del sito
- `cdn_endpoint_url`: URL del CDN (se abilitato)
- `cdn_custom_domain_url`: URL del dominio personalizzato (se configurato)
- `storage_account_id`: ID dello Storage Account





## Comandi
- Inizializzazione
    ```bash
    terraform init

    terraform plan

    terraform apply

    terraform output website_url
    # del tipo https://alnaoterraformes03web.z6.web.core.windows.net/

    SITE_URL=$(terraform output -raw website_url)
    firefox $SITE_URL
    ```
  - Applicazione - Deploy base con nome specifico di un storace
      ```bash
      terraform apply -var="storage_account_name=miosito123web"
      
      # Visualizza l'URL del sito
      terraform output website_url
      # Output: https://miosito123web.z6.web.core.windows.net
      ```
  - Applicazione - Con Azure CDN per dominio personalizzato e performance
      ```bash
      terraform apply \
        -var="storage_account_name=miosito123web" \
        -var="enable_cdn=true"
      
      # Ottieni l'URL del CDN
      terraform output cdn_endpoint_url
      ```
- Upload di file personalizzati
    - Crea una struttura locale:
        ```bash
        # Crea directory per i file
        mkdir -p website-files
        
        # Crea file personalizzati
        cat > website-files/style.css <<EOF
        body { font-family: Arial, sans-serif; }
        EOF
        
        cat > website-files/app.js <<EOF
        console.log('Hello from Azure!');
        EOF
        ```
    - Configura in `terraform.tfvars`:
        ```hcl
        website_files = {
          "css/style.css" = {
            source       = "./website-files/style.css"
            content_type = "text/css"
          }
          "js/app.js" = {
            source       = "./website-files/app.js"
            content_type = "application/javascript"
          }
          "images/logo.png" = {
            source       = "./website-files/logo.png"
            content_type = "image/png"
          }
        }
        ```
    - Applica:
        ```bash
        terraform apply -var="storage_account_name=miosito123web"
        ```
- Con dominio personalizzato
    1. Abilita CDN e configura il dominio:
        ```bash
        terraform apply \
          -var="storage_account_name=miosito123web" \
          -var="enable_cdn=true" \
          -var="custom_domain_name=www.miodominio.com"
        ```
    2. Configura il DNS con un record CNAME:
        ```
        CNAME www.miodominio.com -> miosito123web-endpoint.azureedge.net
        ```
- Upload manuale di file con Azure CLI
    ```bash
    # Upload singolo file
    az storage blob upload \
      --account-name miosito123web \
      --container-name '$web' \
      --name index.html \
      --file ./index.html \
      --content-type text/html
    
    # Upload directory intera
    az storage blob upload-batch \
      --account-name miosito123web \
      --destination '$web' \
      --source ./website-files \
      --pattern "*"
    ```
- Distruzione
    ```bash
    terraform destroy
    ```


## Caratteristiche e configurazioni
- **Caratteristiche principali**
    - Hosting sito web statico su Blob Storage
    - HTTPS nativo tramite endpoint storage
    - Index document e Error document personalizzabili
    - CORS configurato
    - Versioning opzionale
    - Soft delete opzionale
    - HTML di esempio incluso
    - CDN opzionale per performance e dominio personalizzato
    - Compressione automatica con CDN

- **SKU CDN disponibili**
    - **Standard_Microsoft**: Raccomandato, buon rapporto qualità/prezzo
    - **Standard_Akamai**: Performance elevate, costi maggiori
    - **Standard_Verizon**: Analytics avanzate
    - **Premium_Verizon**: Funzionalità premium, WAF

- **Compressione CDN**
    - Il CDN comprime automaticamente questi content-type:
        - text/html, text/css, text/javascript
        - application/json, application/xml

- **Immagini e content types supportati**
    - HTML: text/html
    - CSS: text/css
    - JavaScript: application/javascript
    - JSON: application/json
    - PNG: image/png
    - JPEG: image/jpeg
    - SVG: image/svg+xml
    - PDF: application/pdf

- **Differenze con AWS S3**
  | Caratteristica | AWS S3 | Azure Blob Storage |
  |----------------|--------|-------------------|
  | HTTPS nativo | ❌ (serve CloudFront) | ✅ |
  | Endpoint | `bucket.s3-website-region.amazonaws.com` | `storageaccount.z6.web.core.windows.net` |
  | Container | Bucket | Container $web |
  | CDN | CloudFront | Azure CDN |
  | Custom domain | Route53 o DNS | Azure CDN + DNS |

- **Limitazioni**
  - Solo contenuto statico (HTML, CSS, JS, immagini)
  - No server-side processing (no PHP, no Python, no Node.js)
  - Nome storage account deve essere univoco globalmente
  - Container $web è riservato per static website
  - Custom domain richiede Azure CDN
  - HTTPS su dominio personalizzato richiede CDN

- **Sicurezza**
  - **Limitare l'accesso per IP** (solo per ambienti di sviluppo/staging):
      ```hcl
      network_rules {
        default_action = "Deny"
        ip_rules       = ["YOUR_IP"]
        bypass         = ["AzureServices"]
      }
      ```
      ⚠️ **NOTA**: Questo blocca l'accesso pubblico al sito web. Usare solo per ambienti non pubblici.
  - **HTTPS obbligatorio**: Abilitare CDN con redirect automatico HTTP→HTTPS (già configurato in main.tf)
  - **Versioning e Soft Delete**: Protezione contro cancellazioni accidentali (abilitate di default)


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




