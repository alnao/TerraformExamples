#!/bin/bash
# Deploy script con Blue/Green strategy

set -e
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "🚀 Inizio deploy Azure-Esempio05-Functions"
echo "📅 Timestamp: $TIMESTAMP"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni helper
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}       
log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}
log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}
log_error() {
    echo -e "${RED}❌ $1${NC}"
}   
# Verifica prerequisiti
log_info "Verifica prerequisiti..."
if ! command -v az &> /dev/null; then
    log_error "Azure CLI non trovato. Installare Azure CLI prima di continuare."
    exit 1
fi  
log_success "Prerequisiti verificati"
# Esegui il deploy con Terraform
log_info "Eseguo il deploy con Terraform..."
terraform init
terraform plan -out=tfplan
terraform apply -auto-approve   tfplan
log_success "Deploy Terraform completato"
# Ottieni il comando di deploy della Function App
DEPLOY_CMD=$(terraform output -raw deploy_command)
log_info "Eseguo il deploy del codice della Function App..."
echo $DEPLOY_CMD
eval $DEPLOY_CMD
log_success "Deploy del codice della Function App completato"
echo "🚀 Deploy completato con successo!        "

# Get default host key
FUNCTION_KEY=$(az functionapp keys list -g alnao-terraform-esempio05-functions -n  alnao-terraform-esempio05-functions --query "functionKeys.default" -o tsv)
log_info "Chiave di accesso alla Function App ottenuta: $FUNCTION_KEY"

HOSTNAME=$(terraform output -raw function_app_hostname)
log_info "Hostname della Function App: $HOSTNAME"
# Test della Function App
log_info "Eseguo test della Function App..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOSTNAME/api/list-blobs?code=$FUNCTION_KEY")
if [ "$RESPONSE" -eq 200 ]; then
    log_success "Test della Function App riuscito con codice di risposta HTTP $RESPONSE"
else
    log_error "Test della Function App fallito con codice di risposta HTTP $RESPONSE"
    exit 1
fi  
# Ottieni storage account e container
STORAGE_ACCOUNT=$(terraform output -raw test_storage_account_name)
CONTAINER=$(terraform output -raw test_container_name)
log_info "Storage Account: $STORAGE_ACCOUNT, Container: $CONTAINER"

# Carica alcuni blob di test e verifica la funzione
log_info "Carico blob di test e verifico la funzione..."
echo "Test file 1" > /tmp/test1.txt
echo "Test file 2" > /tmp/test2.txt

# Upload blob
log_info "Caricamento blob di test..."
az storage blob upload -f /tmp/test1.txt -c $CONTAINER -n test1.txt --account-name $STORAGE_ACCOUNT
az storage blob upload -f /tmp/test2.txt -c $CONTAINER -n test/subfolder/test2.txt --account-name $STORAGE_ACCOUNT

log_success "Blob di test caricati"
log_info "Eseguo test della Function App dopo il caricamento dei blob..."
RESPONSE=$(curl -s "http://$HOSTNAME/api/list-blobs?code=$FUNCTION_KEY")
echo "Risposta della Function App:"
echo $RESPONSE  
if [[ $RESPONSE == *"test1.txt"* && $RESPONSE == *"test/subfolder/test2.txt"* ]]; then
    log_success "La Function App ha elencato correttamente i blob."
else
    log_error "La Function App non ha elencato correttamente i blob."
    exit 1
fi
log_success "Test della Function App completato con successo"
echo "🚀 Tutto completato con successo!"






