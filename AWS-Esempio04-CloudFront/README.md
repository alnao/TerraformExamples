# AWS Esempio 04 - CloudFront CDN

Questo esempio mostra come creare una distribuzione Amazon CloudFront per servire contenuti statici da S3 con HTTPS, caching e performance ottimizzate.

## Risorse create

- **S3 Bucket**: Bucket privato per il contenuto origin
- **CloudFront Distribution**: CDN distribution con edge locations globali
- **Origin Access Control (OAC)**: Accesso sicuro da CloudFront a S3
- **S3 Bucket Policy**: Policy per permettere accesso solo da CloudFront
- **Custom Error Responses**: Gestione personalizzata degli errori
- **CloudFront Function**: (Opzionale) Per URL rewrite e redirect
- **Logging Bucket**: (Opzionale) Per access logs
- **SSL/TLS**: Certificato CloudFront o custom ACM
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio04CloudFront/terraform.tfstate`.

## Prerequisiti

- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)
- (Opzionale) Certificato ACM in us-east-1 per dominio personalizzato
- (Opzionale) Dominio registrato e Route53 hosted zone

## Caratteristiche

✅ **HTTPS nativo** con certificato CloudFront  
✅ **Origin Access Control (OAC)** - più sicuro di OAI  
✅ **Compressione automatica** Gzip/Brotli  
✅ **Caching intelligente** con TTL configurabili  
✅ **Edge locations globali** per bassa latenza  
✅ **Custom error pages** 404, 403, etc.  
✅ **Geo-restriction** opzionale  
✅ **WAF integration** opzionale  
✅ **HTTP/2 e HTTP/3** supportati  
✅ **CloudFront Functions** per logica edge  

## Utilizzo

### Inizializzazione

```bash
terraform init
```

### Deploy base

```bash
terraform apply -var="bucket_name=mio-cloudfront-bucket-123"
```

### Visualizzare il sito

```bash
# Ottieni l'URL CloudFront
terraform output cloudfront_url

# L'output sarà: https://d1234567890abc.cloudfront.net
```

### Con dominio personalizzato

Prima, crea un certificato ACM in us-east-1:

```bash
# Dalla console AWS o con AWS CLI
aws acm request-certificate \
  --domain-name www.example.com \
  --validation-method DNS \
  --region us-east-1
```

Poi applica:

```bash
terraform apply \
  -var="bucket_name=mio-cloudfront-123" \
  -var='domain_names=["www.example.com"]' \
  -var="acm_certificate_arn=arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
```

Infine, configura DNS (Route53 o altro provider):

```
CNAME www.example.com -> d1234567890abc.cloudfront.net
```

### Con WAF per sicurezza

```bash
# Prima crea un Web ACL
aws wafv2 create-web-acl \
  --scope CLOUDFRONT \
  --region us-east-1 \
  --name my-web-acl

# Poi applica
terraform apply \
  -var="web_acl_id=arn:aws:wafv2:us-east-1:123456789012:global/webacl/..."
```

### Con logging abilitato

```bash
terraform apply \
  -var="bucket_name=mio-cloudfront-123" \
  -var="enable_logging=true"
```

### Con function per SPA (Single Page Application)

```bash
terraform apply \
  -var="bucket_name=mio-cloudfront-123" \
  -var="create_url_rewrite_function=true"
```

### Invalidare la cache

```bash
# Dopo modifiche al contenuto
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### Distruzione

```bash
# Attenzione: la distribuzione può richiedere 15-30 minuti per essere eliminata
terraform destroy
```

## Configurazione avanzata

### Price Classes

- **PriceClass_100**: Solo USA, Europa, Israele (più economico)
- **PriceClass_200**: + Asia, Africa, Sud America
- **PriceClass_All**: Tutte le edge locations (migliori performance)

```bash
terraform apply -var="price_class=PriceClass_200"
```

### Geo-restriction

Blocca o permetti solo certi paesi:

```hcl
# In terraform.tfvars
geo_restriction_type = "whitelist"
geo_restriction_locations = ["IT", "FR", "DE", "ES"]
```

### Caching aggressivo per siti statici

```hcl
# In terraform.tfvars
min_ttl     = 0
default_ttl = 86400   # 1 giorno
max_ttl     = 31536000 # 1 anno
```

### Custom error responses

```hcl
custom_error_responses = [
  {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html" # SPA fallback
  },
  {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }
]
```

## Costi

CloudFront pricing (approssimativo, regione US/Europe):

- **Data Transfer OUT**:
  - Primi 10 TB/mese: $0.085/GB
  - 10-50 TB/mese: $0.080/GB
  - 50-150 TB/mese: $0.060/GB
  - 150+ TB/mese: $0.040/GB

- **HTTP/HTTPS Requests**:
  - $0.0075 per 10.000 richieste

- **Invalidations**: Primi 1.000 path gratuiti/mese

Esempio: Sito con 100.000 visite/mese (100MB ciascuna):
- Transfer: 10 TB × $0.085 = **$850/mese**
- Requests: 100.000 × $0.0075/10.000 = **$0.75/mese**
- **Totale**: ~$850/mese

## Performance Tips

1. **Compressione**: Sempre abilitata di default
2. **Cache-Control headers**: Impostare sui file S3
3. **Versioning file**: Usare hash nei nomi file (app.v123.js)
4. **Invalidations**: Minimizzare, usare versioning invece
5. **HTTP/2**: Abilitato automaticamente
6. **Regional Edge Caches**: Automatici per oggetti poco richiesti

## Configurazione Route53

```hcl
resource "aws_route53_record" "website" {
  zone_id = "Z123456789ABC"
  name    = "www.example.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
```

## CloudFront Functions vs Lambda@Edge

### CloudFront Functions
- ✅ Più economico ($0.10 per 1M invocazioni)
- ✅ Più veloce (< 1ms)
- ❌ Limitato (max 2ms runtime, no network calls)
- ✅ Ideale per: URL rewrite, header manipulation, redirect

### Lambda@Edge
- ✅ Più potente (Node.js, Python)
- ✅ Network calls permesse
- ❌ Più costoso ($0.60 per 1M invocazioni)
- ❌ Più lento (~5-10ms)
- ✅ Ideale per: A/B testing, auth, dynamic content

## Security Best Practices

1. **OAC instead of OAI**: Sempre usare Origin Access Control
2. **WAF**: Abilitare per protezione DDoS e bot
3. **HTTPS only**: Usare `viewer_protocol_policy = "https-only"`
4. **TLS 1.2+**: Usare `minimum_protocol_version = "TLSv1.2_2021"`
5. **Signed URLs**: Per contenuti privati
6. **Geo-restriction**: Limitare accesso se necessario

## Monitoring

CloudFront fornisce metriche in CloudWatch:

```bash
# Visualizza metriche
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=E123456789ABC \
  --start-time 2025-10-26T00:00:00Z \
  --end-time 2025-10-27T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## Output

- `bucket_name`: Nome del bucket S3
- `cloudfront_distribution_id`: ID della distribution
- `cloudfront_distribution_arn`: ARN della distribution
- `cloudfront_domain_name`: Domain name CloudFront
- `cloudfront_url`: URL completo HTTPS
- `cloudfront_hosted_zone_id`: Zone ID per Route53 alias
- `cloudfront_status`: Status della distribution
- `origin_access_control_id`: ID dell'OAC
- `custom_domain_urls`: URL dei domini personalizzati

## Troubleshooting

### Distribution in stato "InProgress"
Normale durante creazione/aggiornamento. Può richiedere 15-30 minuti.

### 403 Access Denied
- Verificare bucket policy
- Verificare OAC configuration
- Controllare che i file esistano in S3

### Invalidation non funziona
- Attendere propagazione (può richiedere minuti)
- Verificare path corretto (`/*` per tutto)
- Controllare quota invalidations

### Costi elevati
- Verificare data transfer OUT
- Controllare cache hit ratio
- Considerare price class più economica
- Verificare attacchi DDoS (abilitare WAF)

## Limitazioni

- Massimo 25 distributions per account (soft limit)
- Massimo 1.000 invalidations gratuite/mese
- File massimo: 30 GB
- CloudFront Functions: max 10 KB code, 2 ms runtime
- Custom SSL certificate: richiede SNI (non supportato da browser molto vecchi)

## Migrare da S3 Website a CloudFront

1. Bucket diventa privato (no public access)
2. CloudFront diventa entry point pubblico
3. Guadagni: HTTPS, performance, sicurezza
4. Costi: Più alto di S3 alone, ma giustificato

## Riferimenti

- [CloudFront Developer Guide](https://docs.aws.amazon.com/cloudfront/)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
- [Best Practices](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/best-practices.html)
