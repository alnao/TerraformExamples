# Azure Esempio 04 - Azure Front Door

Questo esempio mostra come creare una distribuzione Azure Front Door per servire contenuti statici da Blob Storage con HTTPS, caching, WAF e performance ottimizzate.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**:
- Resource Group: Gruppo di risorse
- Storage Account: Storage con static website per origin
- Front Door Profile: Profilo Front Door (Standard o Premium)
- Front Door Endpoint: Endpoint pubblico
- Origin Group: Gruppo origin con health probes
- Origin: Configurazione origin (Storage Account)
- Route: Routing configuration
- Rule Set: (Opzionale) Regole di caching
- Custom Domain: (Opzionale) Dominio personalizzato
- WAF Policy: (Opzionale) Web Application Firewall (solo Premium)
- Diagnostic Settings: (Opzionale) Logging e monitoring
- Nota: lo stato remoto degli esempi viene salvato nello storage-container `alnaoterraformstorage`, modificare il file `backend.tf` per personalizzare questa configurazione.

**Prerequisiti**
- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva
- (Opzionale) DNS Zone Azure per custom domain
- (Opzionale) Log Analytics Workspace per diagnostics

**Variabili principali**
- `location`: Regione Azure (default: West Europe)
- `storage_account_name`: Nome dello Storage Account (deve essere univoco globalmente, 3-24 caratteri, solo minuscole e numeri)
- `frontdoor_name`: Nome del Front Door profile (default: afd-esempio04)
- `frontdoor_sku`: SKU (Standard_AzureFrontDoor o Premium_AzureFrontDoor)
- `enable_waf`: Abilita WAF (solo Premium, default: false)
- `enable_caching`: Abilita caching (default: false)
- `https_redirect_enabled`: Redirect HTTP→HTTPS (default: true)

**Costi stimati** (West Europe)
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️
- **Standard SKU**:
  - Base: €22/mese
  - Data Transfer OUT (Zone 1 - Europa/USA): €0.081/GB
  - Data Transfer OUT (Zone 2 - Asia/Australia): €0.138/GB
  - Requests: €0.0072 per 10.000
  - Esempio con 10TB/mese e 1M requests (Europa):
    - Base: €22/mese
    - Transfer: 10.000 GB × €0.081 = €810/mese
    - Requests: 100 × €0.0072 = €0.72/mese
    - **Totale**: ~€833/mese
- **Premium SKU**:
  - Base: €260/mese
  - Data Transfer OUT: Come Standard
  - Requests: €0.0144 per 10.000
  - WAF requests: €0.0054 per 10.000
  - Esempio con 1TB/mese e 1M requests (Europa):
    - Base: €260/mese
    - Transfer: 1.000 GB × €0.081 = €81/mese
    - Requests: 100 × €0.0144 = €1.44/mese
    - WAF: 100 × €0.0054 = €0.54/mese
    - **Totale**: ~€343/mese

**Output**
- `resource_group_name`: Nome del Resource Group
- `storage_account_name`: Nome dello Storage Account
- `frontdoor_id`: ID del Front Door profile
- `frontdoor_endpoint_hostname`: Hostname dell'endpoint
- `frontdoor_url`: URL completo HTTPS
- `custom_domain_url`: URL del custom domain
- `origin_hostname`: Hostname dell'origin
- `frontdoor_sku`: SKU utilizzato
- `waf_policy_id`: ID della WAF policy



## Comandi
- Inizializzazione
    ```bash
    terraform init
    ```
- Pianificazione
    ```bash
    terraform plan
    ```
- Applicazione - Deploy Standard (senza WAF)
    ```bash
    terraform apply 

    # Oppure in region diversa
    terraform apply -var="location=eastus"

    # In caso di errore 404 file not found lanciare il comando
    az afd endpoint purge --resource-group alnao-terraform-esempio04-frontdoor \
    --profile-name afd-esempio04 \
    --endpoint-name afd-esempio04-endpoint \
    --content-paths "/index.html" "/css/*"
    
    # Verifica con CURL
    curl -I https://$(terraform output -raw origin_hostname)

    # Visualizza l'URL Front Door
    terraform output frontdoor_url
    # Output: https://afd-esempio04-endpoint-xxx.azurefd.net
    ```
- Applicazione - Deploy Premium (con WAF)
    ```bash
    terraform apply \
      -var="storage_account_name=miofd123" \
      -var="frontdoor_sku=Premium_AzureFrontDoor" \
      -var="enable_waf=true"
    
    # Visualizza l'URL e la WAF policy
    terraform output frontdoor_url
    terraform output waf_policy_id
    ```
- Con custom domain
    1. Prima, crea una DNS Zone:
        ```bash
        az network dns zone create \
          --resource-group alnao-terraform-esempio04-frontdoor \
          --name example.com
        ```
    2. Poi applica con il dominio:
        ```bash
        terraform apply \
          -var="storage_account_name=miofd123" \
          -var="custom_domain_name=www.example.com" \
          -var="dns_zone_id=/subscriptions/YOUR_SUB/resourceGroups/YOUR_RG/providers/Microsoft.Network/dnszones/example.com"
        
        # Visualizza l'URL del custom domain
        terraform output custom_domain_url
        ```
- Con monitoring
    1. Crea Log Analytics Workspace:
        ```bash
        az monitor log-analytics workspace create \
          --resource-group alnao-terraform-esempio04-frontdoor \
          --workspace-name fd-logs
        ```
    2. Applica con diagnostics:
        ```bash
        terraform apply \
          -var="storage_account_name=miofd123" \
          -var="enable_diagnostic_settings=true" \
          -var="log_analytics_workspace_id=/subscriptions/YOUR_SUB/resourceGroups/YOUR_RG/providers/Microsoft.OperationalInsights/workspaces/fd-logs"
        ```
- Purge cache
    ```bash
    # Purge cache per tutto il contenuto
    az afd endpoint purge \
      --resource-group alnao-terraform-esempio04-frontdoor \
      --profile-name afd-esempio04 \
      --endpoint-name afd-esempio04-endpoint \
      --content-paths '/*'
    
    # Purge cache per un path specifico
    az afd endpoint purge \
      --resource-group alnao-terraform-esempio04-frontdoor \
      --profile-name afd-esempio04 \
      --endpoint-name afd-esempio04-endpoint \
      --content-paths '/images/*'
    ```
- Verifica stato e configurazione
    ```bash
    # Stato del Front Door
    az afd profile show \
      --name afd-esempio04 \
      --resource-group alnao-terraform-esempio04-frontdoor
    
    # Stato degli endpoint
    az afd endpoint list \
      --profile-name afd-esempio04 \
      --resource-group alnao-terraform-esempio04-frontdoor \
      --output table
    
    # Verifica health probes
    az afd origin show \
      --profile-name afd-esempio04 \
      --origin-group-name afd-esempio04-origin-group \
      --origin-name afd-esempio04-origin \
      --resource-group alnao-terraform-esempio04-frontdoor

    # Testare endpoint
    curl -I https://afd-esempio04-endpoint-fxg3hwf3ewhacuer.z03.azurefd.net/
    
    # Verifica anche con il browser o con curl completo
    curl https://afd-esempio04-endpoint-fxg3hwf3ewhacuer.z03.azurefd.net/

    # Purge di percorsi specifici
    az afd endpoint purge --resource-group alnao-terraform-esempio04-frontdoor \
      --profile-name afd-esempio04 \
      --endpoint-name afd-esempio04-endpoint \
      --content-paths "/index.html" "/css/*"

    # Verifica lo stato del deployment
    az afd profile show --name afd-esempio04 \
      --resource-group alnao-terraform-esempio04-frontdoor \
      --query deploymentStatus

    # Verifica lo stato della origin
    az afd origin show --resource-group alnao-terraform-esempio04-frontdoor \
      --profile-name afd-esempio04 \
      --origin-group-name afd-esempio04-origin-group \
      --origin-name afd-esempio04-origin \
      --query healthCheckStatus

    ```
- Distruzione
    ```bash
    terraform destroy
    ```


## Caratteristiche e configurazioni
- **Caratteristiche principali**
    - Global CDN con Microsoft Global Network (~118 PoP)
    - HTTPS automatico con certificati gestiti
    - Anycast routing per bassa latenza
    - Split TCP per performance ottimizzate
    - Caching intelligente con Rules Engine
    - Compressione automatica
    - Health probes e failover automatico
    - WAF integrato (Premium SKU) - OWASP, Bot protection
    - DDoS protection nativa
    - Custom domains con certificati gestiti

- **Differenze Standard vs Premium SKU**
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

- **Configurazioni avanzate disponibili**
    - **Caching personalizzato**:
        ```hcl
        static_files_cache_duration = "7.00:00:00" # 7 giorni
        ```
    - **WAF in Detection mode** (solo log, no block):
        ```hcl
        waf_mode = "Detection"
        ```
    - **Protocolli personalizzati**:
        ```hcl
        supported_protocols = ["Https"] # Solo HTTPS
        ```
    - **Health probe personalizzato**:
        ```hcl
        health_probe_interval = 30 # Ogni 30 secondi
        health_probe_path     = "/health"
        ```

- **Rules Engine supportato**
    - Front Door supporta regole avanzate per:
        - URL rewriting
        - Header manipulation
        - Redirect
        - Caching override
        - Origin override
    - Esempio rule in Terraform:
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

- **WAF Managed Rules** (solo Premium)
    - **Default Rule Set (OWASP Core Rule Set)**:
        - SQL Injection
        - Cross-Site Scripting (XSS)
        - Remote File Inclusion
        - Remote Code Execution
        - Protocol violations
    - **Bot Manager Rule Set**:
        - Good bots (Google, Bing)
        - Bad bots (scrapers, scanners)
        - Unknown bots
    - **Custom Rules** esempio:
        ```hcl
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
        ```

- **Confronto con AWS CloudFront**
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

- **Limitazioni**
    - Massimo 500 route per profile
    - Massimo 25 origin per origin group
    - Massimo 100 rules per rule set
    - File size massimo: 130 GB
    - Premium SKU richiesto per WAF e Private Link



- **Security Best Practices**
  1. **Sempre Premium in produzione** per avere WAF integrato
  2. **HTTPS only**: Abilitare `https_redirect_enabled = true` (già di default)
  3. **TLS 1.2+**: Usare `minimum_tls_version = "TLS12"` (già di default)
  4. **Managed rules**: Abilitare Default Rule Set e Bot Manager (Premium)
  5. **Rate limiting**: Configurare custom rules per limitare richieste
  6. **Private origin**: Usare Private Link per connessioni sicure (Premium)
  7. **Geo-filtering**: Limitare paesi se necessario
  8. **Monitoring**: Abilitare diagnostic settings per analisi

- **Monitoring e Diagnostics**
  - **Metriche disponibili in Front Door**:
      - Access Logs: Tutte le richieste HTTP
      - Health Probe Logs: Status degli health checks
      - WAF Logs: Richieste bloccate/permesse (Premium)
      - Metrics: Latency, request count, error rates

  - **Query KQL esempio**:
      ```kusto
      AzureDiagnostics
      | where Category == "FrontDoorAccessLog"
      | where TimeGenerated > ago(1h)
      | summarize count() by httpStatusCode_s
      | order by count_ desc
      ```

  - **Comandi per verifica logs**:
      ```bash
      # Lista degli access logs
      az monitor diagnostic-settings show \
        --name afd-esempio04-diagnostics \
        --resource /subscriptions/YOUR_SUB/resourceGroups/YOUR_RG/providers/Microsoft.Cdn/profiles/afd-esempio04
      
      # Query logs da Log Analytics
      az monitor log-analytics query \
        --workspace YOUR_WORKSPACE_ID \
        --analytics-query "AzureDiagnostics | where Category == 'FrontDoorAccessLog' | take 10"
      ```

- Troubleshooting
  - Endpoint non raggiungibile
    - **Causa**: Provisioning in corso o origin offline
    - **Soluzioni**:
      - Attendere provisioning (può richiedere 10-15 minuti)
      - Verificare che origin sia online:
        ```bash
        curl -I https://$(terraform output -raw origin_hostname)
        ```
      - Controllare health probe status:
        ```bash
        az afd origin show \
          --profile-name afd-esempio04 \
          --origin-group-name afd-esempio04-origin-group \
          --origin-name afd-esempio04-origin \
          --resource-group alnao-terraform-esempio04-frontdoor \
          --query "healthProbeSettings"
        ```
  - Custom domain non funziona
    - **Causa**: DNS non configurato o certificato in provisioning
    - **Soluzioni**:
      - Verificare configurazione DNS (deve puntare all'endpoint Front Door)
      - Attendere propagazione DNS (fino a 48 ore)
      - Verificare certificato SSL (generazione automatica può richiedere tempo):
        ```bash
        az afd custom-domain show \
          --profile-name afd-esempio04 \
          --custom-domain-name www-example-com \
          --resource-group alnao-terraform-esempio04-frontdoor
        ```
  - WAF blocca traffico legittimo
    - **Causa**: Regole troppo restrittive
    - **Soluzioni**:
      - Controllare WAF logs per identificare la regola che blocca:
        ```bash
        az monitor log-analytics query \
          --workspace YOUR_WORKSPACE_ID \
          --analytics-query "AzureDiagnostics | where Category == 'FrontDoorWebApplicationFirewallLog' | where action_s == 'Block'"
        ```
      - Mettere in Detection mode temporaneamente (`waf_mode = "Detection"`)
      - Creare exception rules se necessario
      - Disabilitare regole specifiche se causano falsi positivi
  - Costi elevati inaspettati
    - **Causa**: Troppo data transfer o richieste
    - **Soluzioni**:
      - Verificare data transfer con metriche Azure
      - Ottimizzare caching per ridurre richieste all'origin
      - Considerare Standard SKU se WAF non è necessario
      - Monitorare bot traffic (potrebbe essere necessario bloccare bot malevoli)
      - Verificare compressione sia abilitata:
        ```bash
        az afd route show \
          --profile-name afd-esempio04 \
          --endpoint-name afd-esempio04-endpoint \
          --route-name afd-esempio04-route \
          --resource-group alnao-terraform-esempio04-frontdoor
        ```
  - Cache non funziona correttamente
    - **Causa**: Configurazione cache errata o headers dall'origin
    - **Soluzioni**:
      - Verificare che `enable_caching = true`
      - Controllare cache-control headers dall'origin
      - Purgare cache manualmente per test
      - Verificare regole di caching nel rule set
  - 404 o 502 errors
    - **Causa**: Origin non raggiungibile o misconfigured
    - **Soluzioni**:
      - Verificare che storage account abbia static website abilitato
      - Controllare che i file esistano nel container $web
      - Verificare configurazione origin (hostname, protocol)
      - Testare direttamente l'origin bypassando Front Door
  - Migrare da Azure CDN Standard a Front Door
    - Azure sta deprecando il vecchio Azure CDN a favore di Front Door:
        1. Front Door è la versione moderna e raccomandata
        2. Migliori performance (Anycast routing)
        3. Migliore integrazione con altri servizi Azure
        4. WAF nativo (Premium SKU)
        5. Gestione più semplice e intuitiva
        6. Health probes nativi senza configurazioni complesse


## Riferimenti
- [Azure Front Door Documentation](https://docs.microsoft.com/azure/frontdoor/)
- [Pricing Calculator](https://azure.microsoft.com/pricing/details/frontdoor/)
- [Best Practices](https://docs.microsoft.com/azure/frontdoor/best-practices)
- [WAF Documentation](https://docs.microsoft.com/azure/web-application-firewall/afds/afds-overview)


# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella massima misura possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


Alcuni contenuti e porzioni di codice presenti in questo repository sono stati realizzati anche grazie al supporto di strumenti di intelligenza artificiale, il cui contributo ha permesso di arricchire e velocizzare la produzione del materiale. Ogni informazione e frammento di codice è stato comunque attentamente verificato e validato, con l'obiettivo di garantire la massima qualità e affidabilità dei contenuti offerti. 


Per ulteriori dettagli, approfondimenti o richieste di chiarimento, si invita a consultare il sito [AlNao.it](https://www.alnao.it/).


## License
Made with ❤️ by <a href="https://www.alnao.it">AlNao</a>
&bull; 
Public projects 
<a href="https://www.gnu.org/licenses/gpl-3.0"  valign="middle"> <img src="https://img.shields.io/badge/License-GPL%20v3-blue?style=plastic" alt="GPL v3" valign="middle" /></a>
*Free Software!*


Il software è distribuito secondo i termini della GNU General Public License v3.0. L'uso, la modifica e la ridistribuzione sono consentiti, a condizione che ogni copia o lavoro derivato sia rilasciato con la stessa licenza. Il contenuto è fornito "così com'è", senza alcuna garanzia, esplicita o implicita.


The software is distributed under the terms of the GNU General Public License v3.0. Use, modification, and redistribution are permitted, provided that any copy or derivative work is released under the same license. The content is provided "as is", without any warranty, express or implied.
