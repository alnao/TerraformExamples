#!/bin/bash
# Deploy script con Blue/Green strategy

set -e

PLAN_FILE=$1
ENVIRONMENT=$2
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🚀 Inizio deploy per ambiente: $ENVIRONMENT"
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
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl non trovato. Installare kubectl prima di continuare."
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    log_error "terraform non trovato. Installare terraform prima di continuare."
    exit 1
fi

# Verifica connessione cluster Kubernetes
if ! kubectl cluster-info &> /dev/null; then
    log_error "Impossibile connettersi al cluster Kubernetes"
    exit 1
fi

log_success "Prerequisiti verificati"

# Backup dello stato corrente
log_info "Backup stato corrente..."
terraform state pull > "backup_${ENVIRONMENT}_${TIMESTAMP}.tfstate"

# Salva versione precedente per rollback
PREVIOUS_VERSION=$(terraform output -raw current_version 2>/dev/null || echo "none")
log_info "Versione precedente: $PREVIOUS_VERSION"

# Salva configurazione deployment corrente
DEPLOYMENT_NAME=$(terraform output -raw deployment_name 2>/dev/null || echo "none")
if [ "$DEPLOYMENT_NAME" != "none" ]; then
    kubectl get deployment $DEPLOYMENT_NAME -o yaml > "backup_deployment_${ENVIRONMENT}_${TIMESTAMP}.yaml" 2>/dev/null || true
    log_info "Backup deployment salvato"
fi

# Deploy della nuova versione
log_info "Applicazione nuova configurazione..."
if terraform apply -auto-approve $PLAN_FILE; then
    log_success "Terraform apply completato"
else
    log_error "Terraform apply fallito"
    exit 1
fi

# Attesa che il deployment sia pronto
NEW_DEPLOYMENT_NAME=$(terraform output -raw deployment_name)
NAMESPACE=$(terraform output -raw namespace)

log_info "Attesa completamento rollout deployment..."
if kubectl rollout status deployment/$NEW_DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s; then
    log_success "Rollout completato"
else
    log_error "Rollout timeout o fallito"
    log_warning "Iniziando rollback automatico..."
    ./rollback.sh $ENVIRONMENT $PREVIOUS_VERSION
    exit 1
fi

# Health check
log_info "Controllo salute applicazione..."
APP_URL=$(terraform output -raw app_url)

# Se è un URL locale (port-forward), avvia port-forward in background
if [[ $APP_URL == *"kubectl port-forward"* ]]; then
    log_info "Avvio port-forward per test..."
    SERVICE_NAME=$(terraform output -raw service_name)
    kubectl port-forward svc/$SERVICE_NAME -n $NAMESPACE 8080:80 &
    PORT_FORWARD_PID=$!
    
    # Attesa che port-forward sia pronto
    sleep 5
    APP_URL="http://localhost:8080"
fi

# Esegui health check
chmod +x ./health-check.sh
if ./health-check.sh $APP_URL; then
    log_success "Health check superato"
    
    # Cleanup port-forward se avviato
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
    
    # Informazioni deployment
    CURRENT_VERSION=$(terraform output -raw current_version)
    REPLICAS=$(terraform output -raw replicas)
    
    log_success "Deploy completato con successo!"
    echo ""
    echo "📋 Riepilogo Deploy:"
    echo "   🏷️  Versione: $CURRENT_VERSION"
    echo "   🌍 Ambiente: $ENVIRONMENT"  
    echo "   🔢 Repliche: $REPLICAS"
    echo "   🌐 URL: $APP_URL"
    echo "   📦 Namespace: $NAMESPACE"
    echo ""
    
    # Invia notifica Slack se webhook configurato
    if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚀 Deploy completato con successo!\n• Ambiente: $ENVIRONMENT\n• Versione: $CURRENT_VERSION\n• URL: $APP_URL\"}" \
            $SLACK_WEBHOOK_URL 2>/dev/null || true
    fi
    
else
    log_error "Health check fallito!"
    
    # Cleanup port-forward se avviato
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
    
    log_warning "Iniziando rollback automatico..."
    ./rollback.sh $ENVIRONMENT $PREVIOUS_VERSION
    exit 1
fi
