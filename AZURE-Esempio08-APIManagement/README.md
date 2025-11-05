# AZURE Esempio 08 - API Management

API Management con due API:
- **GET /api/files**: Lista blob da Storage Account
- **POST /api/calculate**: Calcola ipotenusa
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

## Risorse
- API Management (Consumption SKU)
- Function App con 2 functions
- Storage Account per file
- Application Insights
- Backend configuration
- API Operations e Policies

## Utilizzo
```bash
terraform init
terraform apply

# Dopo deploy, configura function key in APIM

# Test GET
curl $(terraform output -raw get_files_url)

# Test POST
curl -X POST $(terraform output -raw post_calculate_url) \
  -H 'Content-Type: application/json' \
  -d '{"cateto_a":3,"cateto_b":4}'
```

## Note
- Il Consumption SKU di APIM è economico ma con limitazioni
- Configurare manualmente la function key in Named Values
- Le function devono essere deployate separatamente

## Costi
- APIM Consumption: $0.035 per 10K chiamate
- Function App: Consumption plan
- Storage: Standard pricing

## Riferimenti
- [API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [APIM Pricing](https://azure.microsoft.com/pricing/details/api-management/)
