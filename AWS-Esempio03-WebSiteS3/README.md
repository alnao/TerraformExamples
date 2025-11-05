# AWS Esempio 03 - Sito Web Statico su S3

Questo esempio mostra come creare e hostare un sito web statico su Amazon S3 usando Terraform.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️
- ⚠️ NOTA: S3 website endpoint supporta solo HTTP. Per HTTPS è necessario CloudFront (vedi AWS-Esempio04-CloudFront). ⚠️


**Risorse create**
- S3 Bucket: Bucket configurato per hosting di siti web statici
- Bucket Website Configuration: Configurazione per index e error document
- Bucket Policy: Policy per accesso pubblico in lettura
- Public Access Block: Configurazione per permettere accesso pubblico
- CORS Configuration: (Opzionale) Configurazione CORS
- Versioning: (Opzionale) Abilitazione versioning
- Logging: (Opzionale) Bucket separato per i log di accesso
- S3 Objects: Upload automatico di index.html e error.html
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio03WebSiteS3/terraform.tfstate`.

**Limitazioni**
- Solo contenuto statico (HTML, CSS, JS, immagini)
- No server-side processing
- Solo HTTP (per HTTPS usare CloudFront)
- Nome bucket deve essere univoco globalmente
- Nome bucket deve seguire regole DNS (minuscole, numeri, trattini)

**Prerequisiti**
- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)
- (Opzionale) File HTML personalizzati da uploadare

**Costi**
- Storage S3: ~$0.023/GB/mese (primi 50 TB)
- Request GET: $0.0004 per 1.000 richieste
- Transfer OUT: $0.09/GB (primi 10 TB/mese)
- Versioning: costo aggiuntivo per versioni multiple
Esempio: Sito da 100MB con 10.000 visite/mese:
- Storage: ~$0.002/mese
- Requests: ~$0.004/mese (10.000 GET)
- Transfer: ~$9/mese (assumendo 1MB per visita)
- **Totale**: ~$9/mese

**Output**
- `bucket_name`: Nome del bucket S3
- `bucket_arn`: ARN del bucket
- `website_endpoint`: Endpoint del sito web
- `website_url`: URL completo del sito web
- `bucket_domain_name`: Domain name del bucket
- `bucket_regional_domain_name`: Regional domain name del bucket

**Troubleshooting**
- Errore "BucketAlreadyExists": Il nome del bucket è già utilizzato. Provare con un nome diverso.
- 403 Forbidden: Verificare che la policy del bucket permetta accesso pubblico e che il public access block sia configurato correttamente.
- 404 Not Found: Verificare che i file siano stati uploadati correttamente e che l'index document esista.
- CORS errors: Verificare che `enable_cors` sia `true` e che gli origin siano configurati correttamente.

## Comandi
- Inizializzazione
  ```bash
  terraform init
  terraform plan
  ```
- Deploy con configurazione di default
  ```bash
  # Il bucket name deve essere univoco globalmente
  terraform apply -var="bucket_name=alnao-aws-terraform-esempio03sito-web"
  ```
- Visualizzare il sito
  ```bash
  # Ottieni URL del sito
  terraform output website_url

  # Apri nel browser
  WEBSITE_URL=$(terraform output -raw website_url)
  firefox $WEBSITE_URL
  # http://aws-esempio03-website.s3-website.eu-central-1.amazonaws.com/
  ```
- Upload di file personalizzati
  Caricare file aggiuntivi creando una struttura locale:
  ```bash
  # Creare directory per i file del sito
  mkdir -p website-files

  # Creare file personalizzati
  cat > website-files/style.css <<EOF
  body { background: #f0f0f0; }
  EOF

  cat > website-files/script.js <<EOF
  console.log('Hello from S3!');
  EOF
  ```

  Poi configurare in `terraform.tfvars`:

  ```hcl
  website_files = {
    "style.css" = {
      source       = "./website-files/style.css"
      content_type = "text/css"
    }
    "script.js" = {
      source       = "./website-files/script.js"
      content_type = "application/javascript"
    }
    "images/logo.png" = {
      source       = "./website-files/logo.png"
      content_type = "image/png"
    }
  }
  ```

- Con logging abilitato
  ```bash
  terraform apply \
    -var="bucket_name=mio-sito-web-123" \
    -var="enable_logging=true"
  ```
- Con HTML personalizzato: creare file `custom-index.html` e applicalo:
  ```bash
  terraform apply \
    -var="bucket_name=mio-sito-web-123" \
    -var="index_html_content=$(cat custom-index.html)"
  ```
- Distruzione

  ```bash
  terraform destroy
  ```

## Configurazione dominio personalizzato

Per usare un dominio personalizzato (es: www.miodominio.com):

1. Il bucket deve avere lo stesso nome del dominio
2. Configurare Route53 o il tuo DNS provider

  ```bash
  terraform apply -var="bucket_name=www.miodominio.com"
  ```
Poi in Route53:
  ```hcl
  resource "aws_route53_record" "website" {
    zone_id = "YOUR_ZONE_ID"
    name    = "www.miodominio.com"
    type    = "A"
    
    alias {
      name                   = aws_s3_bucket_website_configuration.website.website_domain
      zone_id                = aws_s3_bucket.website.hosted_zone_id
      evaluate_target_health = false
    }
  }
  ```

## HTTPS e CloudFront

⚠️ **NOTA**: S3 website endpoint supporta solo HTTP. Per HTTPS è necessario CloudFront (vedi AWS-Esempio04-CloudFront).




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



