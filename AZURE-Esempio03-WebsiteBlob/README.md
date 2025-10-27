# Azure Esempio 03 - Sito Web Statico su Blob Storage

Questo esempio mostra come creare e hostare un sito web statico su Azure Blob Storage usando Terraform.

## Risorse create

- **Resource Group**: Gruppo di risorse per organizzare le risorse
- **Storage Account**: Account storage configurato per static website hosting
- **Static Website**: Configurazione per hosting di siti web statici
- **Blob Storage**: Container $web per i file del sito
- **CORS Configuration**: Configurazione CORS per accesso cross-origin
- **Versioning**: (Opzionale) Versioning dei blob
- **CDN Profile**: (Opzionale) Azure CDN per HTTPS e performance
- **CDN Endpoint**: (Opzionale) Endpoint CDN con compressione
- **Custom Domain**: (Opzionale) Dominio personalizzato

## Prerequisiti

- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva

## Caratteristiche

✅ Hosting sito web statico su Blob Storage  
✅ HTTPS nativo tramite endpoint storage  
✅ Index document e Error document personalizzabili  
✅ CORS configurato  
✅ Versioning opzionale  
✅ Soft delete opzionale  
✅ HTML di esempio incluso  
✅ CDN opzionale per performance e dominio personalizzato  
✅ Compressione automatica con CDN  

## Utilizzo

### Inizializzazione

```bash
terraform init
```

### Deploy con configurazione di default

```bash
# Il nome dello storage account deve essere univoco globalmente
terraform apply -var="storage_account_name=miosito123web"
```

### Visualizzare il sito

```bash
# Ottieni l'URL del sito
terraform output website_url

# L'output sarà simile a: https://miosito123web.z6.web.core.windows.net
```

### Con Azure CDN (per dominio personalizzato e performance)

```bash
terraform apply \
  -var="storage_account_name=miosito123web" \
  -var="enable_cdn=true"

# Ottieni l'URL del CDN
terraform output cdn_endpoint_url
```

### Upload di file personalizzati

Crea una struttura locale:

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

Configura in `terraform.tfvars`:

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

### Con dominio personalizzato

Per usare un dominio personalizzato:

1. Abilita CDN
2. Configura il dominio

```bash
terraform apply \
  -var="storage_account_name=miosito123web" \
  -var="enable_cdn=true" \
  -var="custom_domain_name=www.miodominio.com"
```

3. Configura il DNS:

```
CNAME www.miodominio.com -> miosito123web-endpoint.azureedge.net
```

### Distruzione

```bash
terraform destroy
```

## Differenze con AWS S3

| Caratteristica | AWS S3 | Azure Blob Storage |
|----------------|--------|-------------------|
| HTTPS nativo | ❌ (serve CloudFront) | ✅ |
| Endpoint | `bucket.s3-website-region.amazonaws.com` | `storageaccount.z6.web.core.windows.net` |
| Container | Bucket | Container $web |
| CDN | CloudFront | Azure CDN |
| Custom domain | Route53 o DNS | Azure CDN + DNS |

## Costi stimati (West Europe)

- **Storage**: ~€0.018/GB/mese (Hot tier)
- **Transazioni**: ~€0.004 per 10.000 operazioni
- **Transfer OUT**: €0.087/GB (primi 10 TB)
- **CDN Standard Microsoft**: ~€0.081/GB transfer + €8.00/mese

Esempio: Sito da 100MB con 10.000 visite/mese:
- Storage: ~€0.002/mese
- Transazioni: ~€0.004/mese
- Transfer: ~€8.70/mese (1MB per visita)
- CDN: ~€16.00/mese (se abilitato)

**Totale**: ~€8.70/mese (senza CDN) o ~€24.70/mese (con CDN)

## Configurazione CDN

### SKU disponibili

- **Standard_Microsoft**: Raccomandato, buon rapporto qualità/prezzo
- **Standard_Akamai**: Performance elevate, costi maggiori
- **Standard_Verizon**: Analytics avanzate
- **Premium_Verizon**: Funzionalità premium, WAF

### Compressione

Il CDN comprime automaticamente questi content-type:
- text/html
- text/css
- text/javascript
- application/json
- application/xml

## Output

- `resource_group_name`: Nome del Resource Group
- `storage_account_name`: Nome dello Storage Account
- `primary_web_endpoint`: Endpoint primario del sito
- `primary_web_host`: Host primario
- `website_url`: URL completo del sito
- `cdn_endpoint_url`: URL del CDN (se abilitato)
- `cdn_custom_domain_url`: URL del dominio personalizzato (se configurato)
- `storage_account_id`: ID dello Storage Account

## Upload manuale di file

Puoi anche uploadare file manualmente con Azure CLI:

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

## Best Practices

1. **Nome storage account**: Usare solo minuscole e numeri (3-24 caratteri)
2. **Versioning**: Abilitare per backup automatici
3. **CDN**: Usare per HTTPS su dominio personalizzato
4. **Compressione**: Abilitare per ridurre i costi di bandwidth
5. **Soft delete**: Abilitare per protezione contro cancellazioni accidentali
6. **Caching**: Configurare header di cache appropriati
7. **CORS**: Configurare solo per gli origin necessari

## Troubleshooting

### Errore "StorageAccountAlreadyExists"
Il nome dello storage account è già utilizzato. Provare con un nome diverso.

### 404 Not Found
- Verificare che i file siano nel container `$web`
- Verificare che `index.html` esista
- Controllare che static website sia abilitato

### CORS errors
Verificare che `enable_cors` sia `true` e che gli origin siano configurati correttamente.

### Custom domain non funziona
- Verificare la configurazione CNAME nel DNS
- Attendere la propagazione DNS (può richiedere fino a 48 ore)
- Verificare che il CDN endpoint sia attivo

## Limitazioni

- Solo contenuto statico (HTML, CSS, JS, immagini)
- No server-side processing
- Nome storage account deve essere univoco globalmente
- Container $web è riservato per static website
- Custom domain richiede Azure CDN

## Sicurezza

Per limitare l'accesso per IP:

```hcl
network_rules {
  default_action = "Deny"
  ip_rules       = ["YOUR_IP"]
  bypass         = ["AzureServices"]
}
```

⚠️ **NOTA**: Questo blocca l'accesso pubblico al sito web. Usare solo per ambienti di sviluppo/staging.
