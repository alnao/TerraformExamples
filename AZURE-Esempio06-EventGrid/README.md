# AZURE Esempio 06 - Event Grid

Esempio Azure Function triggerata da Event Grid quando viene caricato un blob in Storage Account.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

## Risorse
- Resource Group
- Storage Account (sorgente)
- Storage Account (function)
- Function App
- Event Grid System Topic
- Event Grid Subscription
- Application Insights
- Metric Alerts (opzionale)

## Utilizzo
```bash
terraform init
terraform apply
```

## Test
```bash
az storage blob upload -f test.txt -c sourcedata -n test.txt --account-name stsource06
```

## Riferimenti
- [Event Grid Documentation](https://docs.microsoft.com/azure/event-grid/)
