#!/bin/bash
# Script di deploy e test per AZURE-Esempio07-LogicApps

set -e

echo "=== Deploy AZURE Esempio 07 - Logic Apps ==="
echo ""

# Cleanup eventuali file temporanei precedenti
rm -f tfplan function.zip 2>/dev/null || true

# Verifica prerequisiti
echo "1. Verifica prerequisiti..."
command -v terraform >/dev/null 2>&1 || { echo "Errore: terraform non installato"; exit 1; }
command -v az >/dev/null 2>&1 || { echo "Errore: azure-cli non installato"; exit 1; }

# Login Azure (se necessario)
echo "2. Verifica autenticazione Azure..."
az account show >/dev/null 2>&1 || {
    echo "Esegui 'az login' prima di continuare"
    exit 1
}

# Terraform Init
echo "3. Inizializzazione Terraform..."
terraform init -upgrade

# Terraform Validate
echo "4. Validazione configurazione..."
terraform validate

# Terraform Format
echo "5. Formattazione codice..."
terraform fmt

# Terraform Plan
echo "6. Creazione piano di esecuzione..."
terraform plan -out=tfplan

# Chiedi conferma
read -p "Vuoi procedere con l'apply? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Terraform Apply
    echo "7. Applicazione configurazione..."
    terraform apply tfplan
    
    # Ottieni output
    echo ""
    echo "=== Deploy completato ==="
    echo ""
    echo "Risorse create:"
    echo "- Resource Group: $(terraform output -raw resource_group_name)"
    echo "- Logic App: $(terraform output -raw logic_app_id)"
    echo "- Function App: $(terraform output -raw function_app_name)"
    echo "- Source Storage: $(terraform output -raw source_storage_name)"
    echo "- Destination Storage: $(terraform output -raw destination_storage_name)"
    echo ""
    echo "Per testare:"
    echo "  az storage blob upload --account-name $(terraform output -raw source_storage_name) \\"
    echo "    --container-name source --name test.txt --file test.txt --auth-mode login"
    echo ""
    echo "Monitora l'esecuzione:"
    echo "  $(terraform output -raw logic_app_url)"
else
    echo "Deploy annullato."
    rm -f tfplan
fi
