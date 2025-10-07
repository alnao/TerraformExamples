#!/bin/bash
# Rollback script per deployment Kubernetes

set -e

ENVIRONMENT=$1
TARGET_VERSION=$2
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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

echo "🔄 Inizio rollback per ambiente: $ENVIRONMENT"
echo "📍 Versione target: $TARGET_VERSION"
echo "📅 Timestamp: $TIMESTAMP"

if [ "$TARGET_VERSION" = "none" ] || [ -z "$TARGET_VERSION" ]; then
    log_error "Nessuna versione precedente disponibile per il rollback"
    log_info "Versioni disponibili nel cluster:"
    kubectl rollout history deployment --all-namespaces 2>/dev/null || true
    exit 1
fi

# Ottieni informazioni deployment corrente
DEPLOYMENT_NAME=$(terraform output -raw deployment_name 2>/dev/null)
NAMESPACE=$(terraform output -raw namespace 2>/dev/null)

if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$NAMESPACE" ]; then
    log_error "Impossibile ottenere informazioni deployment da Terraform"
    log_info "Tentativo ricerca deployment per ambiente..."
    
    # Fallback: cerca deployment per ambiente
    DEPLOYMENT_NAME=$(kubectl get deployments --all-namespaces -l environment=$ENVIRONMENT -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    NAMESPACE=$(kubectl get deployments --all-namespaces -l environment=$ENVIRONMENT -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$NAMESPACE" ]; then
        log_error "Deployment non trovato per ambiente $ENVIRONMENT"
        exit 1
    fi
fi

log_info "Deployment: $DEPLOYMENT_NAME"
log_info "Namespace: $NAMESPACE"

# Verifica esistenza deployment
if ! kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE &>/dev/null; then
    log_error "Deployment $DEPLOYMENT_NAME non trovato nel namespace $NAMESPACE"
    exit 1
fi

# Mostra history rollout
log_info "History rollout corrente:"
kubectl rollout history deployment/$DEPLOYMENT_NAME -n $NAMESPACE

# Salva stato corrente prima del rollback
log_info "Salvataggio stato corrente..."
kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o yaml > "pre_rollback_${DEPLOYMENT_NAME}_${TIMESTAMP}.yaml"

# Esegui rollback Kubernetes deployment
log_info "Rollback deployment Kubernetes..."
if kubectl rollout undo deployment/$DEPLOYMENT_NAME -n $NAMESPACE; then
    log_success "Comando rollback inviato"
else
    log_error "Fallimento comando rollback"
    exit 1
fi

# Attendere completamento rollback
log_info "Attesa completamento rollback..."
if kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s; then
    log_success "Rollback completato"
else
    log_error "Timeout rollback"
    
    # Mostra pod status per debug
    log_info "Status pod per debug:"
    kubectl get pods -n $NAMESPACE -l app=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.metadata.labels.app}')
    
    exit 1
fi

# Verifica health check post-rollback
log_info "Controllo salute post-rollback..."

# Determina URL applicazione
SERVICE_NAME=$(terraform output -raw service_name 2>/dev/null || echo "${DEPLOYMENT_NAME%-*}-service")

# Avvia port-forward per test
log_info "Avvio port-forward per test health..."
kubectl port-forward svc/$SERVICE_NAME -n $NAMESPACE 8080:80 &
PORT_FORWARD_PID=$!

# Attesa che port-forward sia pronto
sleep 5

# Esegui health check
chmod +x ./health-check.sh
APP_URL="http://localhost:8080"

if ./health-check.sh $APP_URL; then
    log_success "Health check post-rollback superato"
    
    # Ottieni versione attuale post-rollback
    CURRENT_IMAGE=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
    CURRENT_VERSION=$(echo $CURRENT_IMAGE | cut -d':' -f2)
    
    log_success "Rollback completato con successo!"
    echo ""
    echo "📋 Riepilogo Rollback:"
    echo "   🏷️  Versione attiva: $CURRENT_VERSION"
    echo "   🌍 Ambiente: $ENVIRONMENT"
    echo "   🔢 Deployment: $DEPLOYMENT_NAME"
    echo "   📦 Namespace: $NAMESPACE"
    echo "   ⏰ Timestamp: $TIMESTAMP"
    echo ""
    
    # Invia notifica Slack se webhook configurato
    if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🔄 Rollback completato per $ENVIRONMENT\n• Versione attiva: $CURRENT_VERSION\n• Deployment: $DEPLOYMENT_NAME\n• Motivo: Health check fallito\"}" \
            $SLACK_WEBHOOK_URL 2>/dev/null || true
    fi
    
else
    log_error "Health check post-rollback fallito!"
    log_error "Intervento manuale necessario"
    
    # Mostra informazioni utili per debug
    log_info "Informazioni debug:"
    echo "   • Deployment: $DEPLOYMENT_NAME"
    echo "   • Namespace: $NAMESPACE"
    echo "   • Service: $SERVICE_NAME"
    
    log_info "Pod status:"
    kubectl get pods -n $NAMESPACE -l app=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.metadata.labels.app}')
    
    log_info "Eventi recenti:"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
    
    # Cleanup port-forward
    kill $PORT_FORWARD_PID 2>/dev/null || true
    
    exit 1
fi

# Cleanup port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true
