#!/bin/bash
# Deploy script per AZURE-Esempio08-APIManagement
# Esegue terraform apply e deploy delle Azure Functions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="${SCRIPT_DIR}/code"

echo "========================================="
echo " AZURE Esempio 08 - API Management"
echo "========================================="

# Step 1: Terraform init & apply
echo ""
echo ">>> Step 1: Terraform init"
cd "$SCRIPT_DIR"
terraform init

echo ""
echo ">>> Step 2: Terraform apply"
terraform apply -auto-approve

# Step 3: Recupera il nome della Function App
FUNCTION_APP_NAME=$(terraform output -raw function_app_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "alnao-terraform-esempio08-apim")

echo ""
echo ">>> Step 3: Deploy Function App code to: $FUNCTION_APP_NAME"

# Deploy con Azure Functions Core Tools
cd "$CODE_DIR"
func azure functionapp publish "$FUNCTION_APP_NAME" --python

echo ""
echo ">>> Step 4: Recupero Function Key per APIM"

# Attendi che la function sia disponibile
sleep 10

# Ottieni la function key
FUNCTION_KEY=$(az functionapp keys list \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "functionKeys.default" -o tsv 2>/dev/null || echo "")

if [ -n "$FUNCTION_KEY" ] && [ "$FUNCTION_KEY" != "" ]; then
    echo "Function Key ottenuta. Aggiornamento Named Value in APIM..."
    
    APIM_NAME=$(terraform output -raw apim_name 2>/dev/null || echo "apim-esempio08")
    
    az apim nv update \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --named-value-id "function-key" \
        --value "$FUNCTION_KEY" \
        --secret true 2>/dev/null || echo "WARN: Aggiorna manualmente la function key nel Named Value di APIM"
else
    echo "WARN: Non è stato possibile ottenere la function key automaticamente."
    echo "       Recuperala manualmente con:"
    echo "       az functionapp keys list --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP"
    echo "       e configurala nel Named Value 'function-key' di APIM."
fi

echo ""
echo "========================================="
echo " Deploy completato!"
echo "========================================="
echo ""
echo "URL API:"
cd "$SCRIPT_DIR"
echo "  GET  files:     $(terraform output -raw get_files_url)"
echo "  POST calculate: $(terraform output -raw post_calculate_url)"
echo ""
echo "Test:"
echo "  curl $(terraform output -raw get_files_url)"
echo "  curl -X POST $(terraform output -raw post_calculate_url) -H 'Content-Type: application/json' -d '{\"cateto_a\":3,\"cateto_b\":4}'"
