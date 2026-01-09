# AZURE Esempio 07 - Logic Apps

Logic App che copia blob da storage A a B e invoca Function per logging.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

## Risorse
- Resource Group
- 3 Storage Accounts (source, destination, function)
- Logic App Workflow
- Function App per logging
- API Connections
- Role Assignments

## Workflow
1. Blob caricato in storage source
2. Logic App trigger attivato
3. Copia blob in destination
4. Invoca Function per log

## Utilizzo
```bash
terraform init
terraform apply
az storage blob upload -f test.txt -c source -n test.txt --account-name stsource07
```

## Note
La definizione completa del workflow Logic App va completata nel portale Azure dopo il deploy Terraform.

## Riferimenti
- [Logic Apps Documentation](https://docs.microsoft.com/azure/logic-apps/)
