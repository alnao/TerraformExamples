# Azure Esempio 04 - Azure Front Door

Questo esempio mostra come creare una distribuzione Azure Front Door per servire contenuti statici da Blob Storage con HTTPS, caching, WAF e performance ottimizzate.

## Risorse create

- **Resource Group**: Gruppo di risorse
- **Storage Account**: Storage con static website per origin
- **Front Door Profile**: Profilo Front Door (Standard o Premium)
- **Front Door Endpoint**: Endpoint pubblico
- **Origin Group**: Gruppo origin con health probes
- **Origin**: Configurazione origin (Storage Account)
- **Route**: Routing configuration
- **Rule Set**: (Opzionale) Regole di caching
- **Custom Domain**: (Opzionale) Dominio personalizzato
- **WAF Policy**: (Opzionale) Web Application Firewall (solo Premium)
- **Diagnostic Settings**: (Opzionale) Logging e monitoring

## Prerequisiti

- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva
- (Opzionale) DNS Zone Azure per custom domain
- (Opzionale) Log Analytics Workspace per diagnostics

## Caratteristiche

✅ **Global CDN** con Microsoft Global Network  
✅ **HTTPS automatico** con certificati gestiti  
✅ **Anycast routing** per bassa latenza  
✅ **Split TCP** per performance  
✅ **Caching intelligente** con Rules Engine  
✅ **Compressione automatica**  
✅ **Health probes** e failover automatico  
✅ **WAF integrato** (Premium SKU) - OWASP, Bot protection  
✅ **DDoS protection** nativa  
✅ **Custom domains** con certificati gestiti  

## Differenze Standard vs Premium

| Caratteristica | Standard | Premium |
|----------------|----------|---------|
| Prezzo | ~€22/mese | ~€260/mese |
| CDN globale | ✅ | ✅ |
| HTTPS | ✅ | ✅ |
| Caching | ✅ | ✅ |
| WAF | ❌ | ✅ |
| Private Link | ❌ | ✅ |
| Managed rules | ❌ | ✅ |
| Bot protection | ❌ | ✅ |

## Utilizzo

### Inizializzazione

```bash
terraform init
```

### Deploy Standard (senza WAF)

```bash
terraform apply \
  -var="storage_account_name=miofd123" \
  -var="frontdoor_sku=Standard_AzureFrontDoor"
```

### Deploy Premium (con WAF)

```bash
terraform apply \
  -var="storage_account_name=miofd123" \
  -var="frontdoor_sku=Premium_AzureFrontDoor" \
  -var="enable_waf=true"
```

### Visualizzare il sito

```bash
# Ottieni l'URL Front Door
terraform output frontdoor_url

# L'output sarà: https://afd-esempio04-endpoint-xxx.azurefd.net
```

### Con custom domain

Prima, crea una DNS Zone:

```bash
az network dns zone create \
  --resource-group rg-frontdoor-example \
  --name example.com
```

Poi applica:

```bash
terraform apply \
  -var="storage_account_name=miofd123" \
  -var="custom_domain_name=www.example.com" \
  -var="dns_zone_id=/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/dnszones/example.com"
```

### Con monitoring

Prima, crea Log Analytics Workspace:

```bash
az monitor log-analytics workspace create \
  --resource-group rg-frontdoor-example \
  --workspace-name fd-logs
```

Poi applica:

```bash
terraform apply \
  -var="storage_account_name=miofd123" \
  -var="enable_diagnostic_settings=true" \
  -var="log_analytics_workspace_id=/subscriptions/.../..."
```

### Purge cache

```bash
# Purge cache per tutto il contenuto
az afd endpoint purge \
  --resource-group rg-frontdoor-example \
  --profile-name afd-esempio04 \
  --endpoint-name afd-esempio04-endpoint \
  --content-paths '/*'
```

### Distruzione

```bash
terraform destroy
```

## Confronto con AWS CloudFront

| Caratteristica | Azure Front Door | AWS CloudFront |
|----------------|------------------|----------------|
| Edge locations | ~118 PoP | ~400+ PoP |
| WAF integrato | ✅ (Premium) | Via AWS WAF |
| Health probes | ✅ Nativi | Lambda@Edge |
| Private origin | ✅ (Premium) | Via VPC |
| Certificati SSL | ✅ Automatici | ✅ Via ACM |
| Caching | Rules Engine | CloudFront Functions |
| Anycast | ✅ | ❌ |
| Prezzo base | ~€22/mese | Pay-per-use |

## Costi stimati

### Standard SKU
- **Base**: €22/mese
- **Data Transfer OUT**:
  - Zone 1 (Europa, USA): €0.081/GB
  - Zone 2 (Asia, Australia): €0.138/GB
- **Requests**: €0.0072 per 10.000

### Premium SKU
- **Base**: €260/mese
- **Data Transfer OUT**: Come Standard
- **Requests**: €0.0144 per 10.000
- **WAF requests**: €0.0054 per 10.000

Esempio (Standard, 10TB/mese, Europa):
- Base: €22/mese
- Transfer: 10.000 GB × €0.081 = €810/mese
- Requests (1M): 100 × €0.0072 = €0.72/mese
- **Totale**: ~€833/mese

## Configurazione avanzata

### Caching personalizzato

```hcl
static_files_cache_duration = "7.00:00:00" # 7 giorni
```

### WAF in Detection mode (solo log, no block)

```hcl
waf_mode = "Detection"
```

### Protocolli personalizzati

```hcl
supported_protocols = ["Https"] # Solo HTTPS
```

### Health probe personalizzato

```hcl
health_probe_interval = 30 # Ogni 30 secondi
health_probe_path     = "/health"
```

## Rules Engine

Front Door supporta regole avanzate per:
- URL rewriting
- Header manipulation
- Redirect
- Caching override
- Origin override

Esempio in Terraform:

```hcl
resource "azurerm_cdn_frontdoor_rule" "redirect" {
  name                      = "RedirectRule"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.main.id
  order                     = 1

  conditions {
    request_uri_condition {
      operator     = "BeginsWith"
      match_values = ["/old"]
    }
  }

  actions {
    url_redirect_action {
      redirect_type        = "PermanentRedirect"
      destination_hostname = "example.com"
      destination_path     = "/new"
    }
  }
}
```

## WAF Managed Rules

Front Door Premium include:

### Default Rule Set (OWASP Core Rule Set)
- SQL Injection
- Cross-Site Scripting (XSS)
- Remote File Inclusion
- Remote Code Execution
- Protocol violations

### Bot Manager Rule Set
- Good bots (Google, Bing)
- Bad bots (scrapers, scanners)
- Unknown bots

### Custom Rules

```hcl
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  # ... managed rules ...

  custom_rule {
    name     = "RateLimitRule"
    enabled  = true
    priority = 100
    type     = "RateLimitRule"
    action   = "Block"

    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 100

    match_condition {
      match_variable = "RemoteAddr"
      operator       = "IPMatch"
      match_values   = ["0.0.0.0/0"]
    }
  }
}
```

## Security Best Practices

1. **Sempre Premium in produzione** per WAF
2. **HTTPS only**: `https_redirect_enabled = true`
3. **TLS 1.2+**: `minimum_tls_version = "TLS12"`
4. **Managed rules**: Abilitare Default Rule Set e Bot Manager
5. **Rate limiting**: Configurare custom rules
6. **Private origin**: Usare Private Link (Premium)
7. **Geo-filtering**: Limitare paesi se necessario
8. **Monitoring**: Abilitare diagnostic settings

## Monitoring e Diagnostics

Front Door fornisce queste metriche:

- **Access Logs**: Tutte le richieste HTTP
- **Health Probe Logs**: Status degli health checks
- **WAF Logs**: Richieste bloccate/permesse
- **Metrics**: Latency, request count, error rates

Query KQL esempio:

```kusto
AzureDiagnostics
| where Category == "FrontDoorAccessLog"
| where TimeGenerated > ago(1h)
| summarize count() by httpStatusCode_s
| order by count_ desc
```

## Output

- `resource_group_name`: Nome del Resource Group
- `storage_account_name`: Nome dello Storage Account
- `frontdoor_id`: ID del Front Door profile
- `frontdoor_endpoint_hostname`: Hostname dell'endpoint
- `frontdoor_url`: URL completo HTTPS
- `custom_domain_url`: URL del custom domain
- `origin_hostname`: Hostname dell'origin
- `frontdoor_sku`: SKU utilizzato
- `waf_policy_id`: ID della WAF policy

## Troubleshooting

### Endpoint non raggiungibile
- Attendere provisioning (può richiedere 10-15 minuti)
- Verificare che origin sia online
- Controllare health probe status

### Custom domain non funziona
- Verificare configurazione DNS
- Attendere propagazione DNS (fino a 48 ore)
- Verificare certificato SSL (generazione automatica)

### WAF blocca traffico legittimo
- Controllare WAF logs
- Mettere in Detection mode temporaneamente
- Creare exception rules se necessario

### Costi elevati
- Verificare data transfer
- Ottimizzare caching
- Considerare Standard SKU se WAF non necessario
- Monitorare bot traffic

## Limitazioni

- Massimo 500 route per profile
- Massimo 25 origin per origin group
- Massimo 100 rules per rule set
- File size massimo: 130 GB
- Premium SKU richiesto per WAF e Private Link

## Migrare da CDN Standard a Front Door

Azure sta deprecando il vecchio Azure CDN a favore di Front Door:

1. Front Door è la versione moderna
2. Migliori performance (Anycast)
3. Migliore integrazione con Azure
4. WAF nativo (Premium)
5. Gestione più semplice

## Riferimenti

- [Azure Front Door Documentation](https://docs.microsoft.com/azure/frontdoor/)
- [Pricing Calculator](https://azure.microsoft.com/pricing/details/frontdoor/)
- [Best Practices](https://docs.microsoft.com/azure/frontdoor/best-practices)
- [WAF Documentation](https://docs.microsoft.com/azure/web-application-firewall/afds/afds-overview)
