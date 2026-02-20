# AZURE Esempio 08 - API Management

API Management con Azure Functions come backend, espone due API REST:
- **GET /api/files** - Lista il contenuto (blob) di un container in uno Storage Account
- **POST /api/calculate** - Calcola l'ipotenusa dati i due cateti
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attenzione prima di eseguire qualsiasi comando ⚠️

## Architettura

```
Client  →  API Management  →  Azure Function App  →  Storage Account
                                    │
                                    ├── list-blobs (GET)
                                    └── calculate-hypotenuse (POST)
```

### Risorse create
| Risorsa | Descrizione |
|---------|-------------|
| Resource Group | Contenitore per tutte le risorse |
| Storage Account (files) | Storage per i blob da listare via API |
| Storage Account (function) | Storage interno per la Function App |
| Application Insights | Monitoraggio e logging |
| Service Plan (Consumption Y1) | Piano di hosting per le Functions |
| Linux Function App | App con due HTTP trigger (Python 3.11) |
| API Management (Consumption) | Gateway API con due operazioni |
| APIM Backend | Collegamento APIM → Function App |
| APIM Named Value | Chiave di autenticazione per le Functions |

## API Endpoints

### GET /api/files
Lista i blob nel container `files` dello Storage Account.

**Query Parameters:**
| Parametro | Tipo | Obbligatorio | Descrizione |
|-----------|------|:------------:|-------------|
| `path` | string | No | Prefisso per filtrare i blob |

**Esempio richiesta:**
```bash
# Lista tutti i blob
curl https://<apim-name>.azure-api.net/api/files

# Filtra per prefisso
curl https://<apim-name>.azure-api.net/api/files?path=folder1
```

**Esempio risposta:**
```json
{
  "container": "files",
  "path": "",
  "count": 2,
  "blobs": [
    {
      "name": "document.pdf",
      "size": 12345,
      "last_modified": "2026-01-15T10:30:00+00:00",
      "content_type": "application/pdf",
      "blob_type": "BlockBlob"
    }
  ]
}
```

### POST /api/calculate
Calcola l'ipotenusa dati due cateti usando il teorema di Pitagora: $c = \sqrt{a^2 + b^2}$

**Request Body (JSON):**
| Campo | Tipo | Obbligatorio | Descrizione |
|-------|------|:------------:|-------------|
| `cateto_a` | number | Sì | Primo cateto (> 0) |
| `cateto_b` | number | Sì | Secondo cateto (> 0) |

**Esempio richiesta:**
```bash
curl -X POST https://<apim-name>.azure-api.net/api/calculate \
  -H 'Content-Type: application/json' \
  -d '{"cateto_a": 3, "cateto_b": 4}'
```

**Esempio risposta:**
```json
{
  "cateto_a": 3.0,
  "cateto_b": 4.0,
  "ipotenusa": 5.0,
  "formula": "sqrt(cateto_a² + cateto_b²)"
}
```

## Struttura del progetto

```
AZURE-Esempio08-APIManagement/
├── backend.tf              # Configurazione backend Terraform
├── main.tf                 # Risorse Terraform (APIM, Functions, Storage, ...)
├── variables.tf            # Variabili con valori di default
├── outputs.tf              # Output (URL, nomi risorse)
├── deploy-all.sh           # Script di deploy completo
├── README.md               # Questa documentazione
└── code/                   # Codice Azure Functions
    ├── function_app.py     # Due HTTP trigger: list_blobs + calculate_hypotenuse
    ├── host.json           # Configurazione runtime Functions
    └── requirements.txt    # Dipendenze Python
```

## Prerequisiti

- [Terraform CLI](https://www.terraform.io/downloads)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Functions Core Tools v4](https://docs.microsoft.com/azure/azure-functions/functions-run-tools)
- Login Azure: `az login`

## Utilizzo

### Deploy completo (consigliato)
```bash
chmod +x deploy-all.sh
./deploy-all.sh
```

### Deploy manuale passo-passo
```bash
# 1. Provisioning infrastruttura
terraform init
terraform apply

# 2. Deploy codice Functions
cd code
func azure functionapp publish $(terraform output -raw function_app_name) --python
cd ..

# 3. Configura function key in APIM Named Value
FUNCTION_KEY=$(az functionapp keys list \
    --name $(terraform output -raw function_app_name) \
    --resource-group $(terraform output -raw resource_group_name) \
    --query "functionKeys.default" -o tsv)

az apim nv update \
    --resource-group $(terraform output -raw resource_group_name) \
    --service-name $(terraform output -raw apim_name) \
    --named-value-id "function-key" \
    --value "$FUNCTION_KEY" \
    --secret true
```

### Test
```bash
# GET - Lista file
curl $(terraform output -raw get_files_url)

# POST - Calcola ipotenusa (3,4,5)
curl -X POST $(terraform output -raw post_calculate_url) \
  -H 'Content-Type: application/json' \
  -d '{"cateto_a":3,"cateto_b":4}'

# POST - Calcola ipotenusa (5,12,13)
curl -X POST $(terraform output -raw post_calculate_url) \
  -H 'Content-Type: application/json' \
  -d '{"cateto_a":5,"cateto_b":12}'
```

### Pulizia risorse
```bash
terraform destroy
```

## Note
- Il Consumption SKU di APIM è il più economico ma ha limitazioni (cold start, rate limiting)
- La function key deve essere configurata nel Named Value di APIM dopo il primo deploy
- Le Functions usano il Python v2 programming model
- Lo Storage Account `files` è quello di cui viene esposto il contenuto via API

## Costi stimati
| Risorsa | Costo |
|---------|-------|
| APIM Consumption | ~$0.035 per 10K chiamate |
| Function App (Consumption) | Primo milione di esecuzioni gratis/mese |
| Storage Account | ~$0.02/GB/mese |
| Application Insights | Primi 5GB/mese gratis |

## Riferimenti
- [API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [Azure Functions Python Developer Guide](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)
- [APIM Policies](https://docs.microsoft.com/azure/api-management/api-management-policies)
- [APIM Pricing](https://azure.microsoft.com/pricing/details/api-management/)
