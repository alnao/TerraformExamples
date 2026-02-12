#!/bin/bash
# Script per configurare il workflow della Logic App dopo il deploy Terraform
# Questo script configura trigger e actions che Terraform non può gestire direttamente

set -e

echo "=== Configurazione Logic App Workflow ==="
echo ""

# Verifica che Terraform sia stato eseguito controllando gli output
if ! terraform output resource_group_name &>/dev/null; then
    echo "Errore: Esegui prima 'terraform apply'"
    echo "Gli output Terraform non sono disponibili."
    exit 1
fi

# Ottieni informazioni dalle output Terraform
RG_NAME=$(terraform output -raw resource_group_name)
LOGIC_APP_NAME=$(terraform output -raw logic_app_id | awk -F'/' '{print $NF}')
SOURCE_STORAGE=$(terraform output -raw source_storage_name)
DEST_STORAGE=$(terraform output -raw destination_storage_name)
FUNCTION_URL=$(terraform output -raw function_app_url)

echo "Resource Group: $RG_NAME"
echo "Logic App: $LOGIC_APP_NAME"
echo "Source Storage: $SOURCE_STORAGE"
echo "Destination Storage: $DEST_STORAGE"
echo "Function URL: $FUNCTION_URL"
echo ""

# Crealo script per configurare il workflow usando Azure CLI
echo "Per configurare il workflow manualmente, segui questi passaggi:"
echo ""
echo "1. Apri il portale Azure:"
echo "   https://portal.azure.com/#@/resource$(terraform output -raw logic_app_id)"
echo ""
echo "2. Vai su 'Logic app designer'"
echo ""
echo "3. Aggiungi Trigger 'When a blob is added or modified (properties only)'"
echo "   - Storage account: $SOURCE_STORAGE"
echo "   - Container: /source"
echo "   - Interval: 1 Minute"
echo ""
echo "4. Aggiungi Action 'Copy blob'"
echo "   - Source: Dynamic content from trigger"
echo "   - Destination: /destination/{Name from trigger}"
echo "   - Storage account: $SOURCE_STORAGE (o usa la stessa connection)"
echo ""
echo "5. Aggiungi Action 'HTTP'"
echo "   - Method: POST"
echo "   - URI: $FUNCTION_URL/api/logger"
echo "   - Headers: Content-Type: application/json"
echo "   - Body:"
echo '     {'
echo '       "blobName": "@{triggerBody()?['"'"'Name'"'"']}",   '
echo '       "sourceContainer": "source",'
echo '       "destinationContainer": "destination",'
echo '       "operationTime": "@{utcNow()}"'
echo '     }'
echo ""
echo "6. Salva e abilita la Logic App"
echo ""

# Opzione: usa Azure CLI per creare il workflow (richiede il file JSON)
read -p "Vuoi configurare automaticamente il workflow da logic_app_workflow.json? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ ! -f "logic_app_workflow.json" ]; then
        echo "Errore: File logic_app_workflow.json non trovato"
        exit 1
    fi
    
    echo "Configurazione workflow utilizzando Azure CLI..."
    
    # Questo comando richiede ulteriore personalizzazione del JSON
    echo "Nota: Il file JSON di esempio richiede modifiche manuali per includere"
    echo "gli ID corretti delle API connections e parametrizzazione."
    echo ""
    echo "Comando di riferimento:"
    echo "az resource update --resource-group $RG_NAME --name $LOGIC_APP_NAME --resource-type Microsoft.Logic/workflows --set properties=@logic_app_workflow.json"
else
    echo "Configurazione manuale richiesta tramite portale Azure."
fi

echo ""
echo "=== Script completato ==="
