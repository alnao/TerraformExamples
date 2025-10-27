# AWS Esempio 03 - Sito Web Statico su S3

Questo esempio mostra come creare e hostare un sito web statico su Amazon S3 usando Terraform.

## Risorse create

- **S3 Bucket**: Bucket configurato per hosting di siti web statici
- **Bucket Website Configuration**: Configurazione per index e error document
- **Bucket Policy**: Policy per accesso pubblico in lettura
- **Public Access Block**: Configurazione per permettere accesso pubblico
- **CORS Configuration**: (Opzionale) Configurazione CORS
- **Versioning**: (Opzionale) Abilitazione versioning
- **Logging**: (Opzionale) Bucket separato per i log di accesso
- **S3 Objects**: Upload automatico di index.html e error.html
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio03WebSiteS3/terraform.tfstate`.

## Prerequisiti

- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)
- (Opzionale) File HTML personalizzati da uploadare

## Caratteristiche

✅ Hosting sito web statico  
✅ Accesso pubblico configurato automaticamente  
✅ Index document e Error document personalizzabili  
✅ CORS abilitato di default  
✅ Versioning opzionale  
✅ Logging opzionale  
✅ HTML di esempio incluso  
✅ Upload automatico di file aggiuntivi

## Utilizzo

### Inizializzazione

```bash
terraform init
```

### Deploy con configurazione di default

```bash
# Il bucket name deve essere univoco globalmente
terraform apply -var="bucket_name=mio-sito-web-unico-123"
```

### Visualizzare il sito

```bash
# Ottieni l'URL del sito
terraform output website_url

# Apri nel browser
# L'output sarà simile a: http://mio-sito-web-unico-123.s3-website.eu-central-1.amazonaws.com
```

### Upload di file personalizzati

Puoi caricare file aggiuntivi creando una struttura locale:

```bash
# Crea directory per i file del sito
mkdir -p website-files

# Crea file personalizzati
cat > website-files/style.css <<EOF
body { background: #f0f0f0; }
EOF

cat > website-files/script.js <<EOF
console.log('Hello from S3!');
EOF
```

Poi configura in `terraform.tfvars`:

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

### Con logging abilitato

```bash
terraform apply \
  -var="bucket_name=mio-sito-web-123" \
  -var="enable_logging=true"
```

### Con HTML personalizzato

Crea file `custom-index.html` e applicalo:

```bash
terraform apply \
  -var="bucket_name=mio-sito-web-123" \
  -var="index_html_content=$(cat custom-index.html)"
```

### Distruzione

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

## Redirect rules

Esempio di redirect da una pagina all'altra:

```hcl
routing_rules = [
  {
    condition = {
      key_prefix_equals = "old-page.html"
    }
    redirect = {
      replace_key_with = "new-page.html"
    }
  }
]
```

## Costi

- **Storage S3**: ~$0.023/GB/mese (primi 50 TB)
- **Request GET**: $0.0004 per 1.000 richieste
- **Transfer OUT**: $0.09/GB (primi 10 TB/mese)
- **Versioning**: costo aggiuntivo per versioni multiple

Esempio: Sito da 100MB con 10.000 visite/mese:
- Storage: ~$0.002/mese
- Requests: ~$0.004/mese (10.000 GET)
- Transfer: ~$9/mese (assumendo 1MB per visita)
- **Totale**: ~$9/mese

## HTTPS e CloudFront

⚠️ **NOTA**: S3 website endpoint supporta solo HTTP. Per HTTPS è necessario CloudFront (vedi AWS-Esempio04-CloudFront).

## Output

- `bucket_name`: Nome del bucket S3
- `bucket_arn`: ARN del bucket
- `website_endpoint`: Endpoint del sito web
- `website_url`: URL completo del sito web
- `bucket_domain_name`: Domain name del bucket
- `bucket_regional_domain_name`: Regional domain name del bucket

## Testing locale

Prima di fare il deploy, puoi testare i file HTML localmente:

```bash
# Con Python
python3 -m http.server 8000

# Apri http://localhost:8000
```

## Limitazioni

- Solo contenuto statico (HTML, CSS, JS, immagini)
- No server-side processing
- Solo HTTP (per HTTPS usare CloudFront)
- Nome bucket deve essere univoco globalmente
- Nome bucket deve seguire regole DNS (minuscole, numeri, trattini)

## Best Practices

1. **Nome bucket**: Usare un nome descrittivo e univoco
2. **Versioning**: Abilitare per backup automatici
3. **HTTPS**: Usare CloudFront per connessioni sicure
4. **CDN**: Usare CloudFront per performance migliori
5. **Compressione**: Comprimere file CSS/JS prima dell'upload
6. **Cache**: Configurare header di cache appropriati
7. **Monitoring**: Abilitare logging per analisi accessi

## Troubleshooting

### Errore "BucketAlreadyExists"
Il nome del bucket è già utilizzato. Provare con un nome diverso.

### 403 Forbidden
Verificare che la policy del bucket permetta accesso pubblico e che il public access block sia configurato correttamente.

### 404 Not Found
Verificare che i file siano stati uploadati correttamente e che l'index document esista.

### CORS errors
Verificare che `enable_cors` sia `true` e che gli origin siano configurati correttamente.
