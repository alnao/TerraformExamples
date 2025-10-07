#!/bin/bash
# Health check script per applicazione

URL=$1
MAX_ATTEMPTS=${2:-30}
SLEEP_TIME=${3:-10}

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

if [ -z "$URL" ]; then
    log_error "URL non specificato"
    echo "Uso: $0 <URL> [max_attempts] [sleep_time]"
    exit 1
fi

log_info "Controllo salute applicazione: $URL"
log_info "Tentativi massimi: $MAX_ATTEMPTS"
log_info "Intervallo: $SLEEP_TIME secondi"

# Array per tracciare i risultati
declare -a test_results=()

for i in $(seq 1 $MAX_ATTEMPTS); do
    echo ""
    log_info "🔄 Tentativo $i/$MAX_ATTEMPTS..."
    
    # Test 1: Health endpoint
    log_info "Test health endpoint..."
    HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/health" --max-time 10 2>/dev/null || echo "000")
    
    if [ "$HEALTH_CODE" = "200" ]; then
        log_success "Health endpoint OK (200)"
        test_results+=("health:ok")
    else
        log_warning "Health endpoint FAIL ($HEALTH_CODE)"
        test_results+=("health:fail")
    fi
    
    # Test 2: Readiness endpoint  
    log_info "Test readiness endpoint..."
    READY_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/ready" --max-time 10 2>/dev/null || echo "000")
    
    if [ "$READY_CODE" = "200" ]; then
        log_success "Readiness endpoint OK (200)"
        test_results+=("ready:ok")
    else
        log_warning "Readiness endpoint FAIL ($READY_CODE)"
        test_results+=("ready:fail")
    fi
    
    # Test 3: Main page
    log_info "Test pagina principale..."
    MAIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/" --max-time 10 2>/dev/null || echo "000")
    
    if [ "$MAIN_CODE" = "200" ]; then
        log_success "Pagina principale OK (200)"
        test_results+=("main:ok")
    else
        log_warning "Pagina principale FAIL ($MAIN_CODE)"
        test_results+=("main:fail")
    fi
    
    # Test 4: API Status (se disponibile)
    log_info "Test API status..."
    API_RESPONSE=$(curl -s "$URL/api/status" --max-time 10 2>/dev/null || echo "")
    
    if echo "$API_RESPONSE" | grep -q "OK" 2>/dev/null; then
        log_success "API status OK"
        test_results+=("api:ok")
    else
        log_warning "API status FAIL o non disponibile"
        test_results+=("api:fail")
    fi
    
    # Valuta risultati
    success_count=$(printf '%s\n' "${test_results[@]}" | grep -c ":ok" || echo "0")
    total_tests=4
    
    log_info "Test passati: $success_count/$total_tests"
    
    # Se almeno 3 test su 4 passano, considera OK
    if [ "$success_count" -ge 3 ]; then
        log_success "Applicazione HEALTHY! 🎉"
        
        # Test aggiuntivi se tutti i test base passano
        if [ "$success_count" -eq 4 ]; then
            log_info "Eseguendo test aggiuntivi..."
            
            # Test response time
            RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$URL/health" --max-time 10 2>/dev/null || echo "999")
            if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo "0") )); then
                log_success "Response time OK: ${RESPONSE_TIME}s"
            else
                log_warning "Response time lento: ${RESPONSE_TIME}s"
            fi
            
            # Test content-type
            CONTENT_TYPE=$(curl -s -I "$URL/" --max-time 10 2>/dev/null | grep -i "content-type" | cut -d' ' -f2- || echo "unknown")
            if echo "$CONTENT_TYPE" | grep -q "text/html" 2>/dev/null; then
                log_success "Content-Type OK: $CONTENT_TYPE"
            else
                log_warning "Content-Type: $CONTENT_TYPE"
            fi
        fi
        
        echo ""
        log_success "🏥 HEALTH CHECK SUPERATO!"
        echo ""
        echo "📊 Riepilogo:"
        echo "   • Health endpoint: $(echo "${test_results[@]}" | grep -o "health:[^[:space:]]*" | cut -d: -f2)"
        echo "   • Readiness endpoint: $(echo "${test_results[@]}" | grep -o "ready:[^[:space:]]*" | cut -d: -f2)"  
        echo "   • Pagina principale: $(echo "${test_results[@]}" | grep -o "main:[^[:space:]]*" | cut -d: -f2)"
        echo "   • API status: $(echo "${test_results[@]}" | grep -o "api:[^[:space:]]*" | cut -d: -f2)"
        echo "   • Tentativi necessari: $i/$MAX_ATTEMPTS"
        echo ""
        
        exit 0
    fi
    
    # Reset risultati per prossima iterazione
    test_results=()
    
    if [ $i -lt $MAX_ATTEMPTS ]; then
        log_info "⏳ Attesa $SLEEP_TIME secondi prima del prossimo tentativo..."
        sleep $SLEEP_TIME
    fi
done

echo ""
log_error "🚨 HEALTH CHECK FALLITO!"
echo ""
echo "❌ Dettagli fallimento:"
echo "   • URL testato: $URL"
echo "   • Tentativi effettuati: $MAX_ATTEMPTS"
echo "   • Durata totale: $((MAX_ATTEMPTS * SLEEP_TIME)) secondi"
echo ""
log_error "L'applicazione non risponde correttamente dopo $MAX_ATTEMPTS tentativi"

# Suggerimenti per debug
echo ""
log_info "🔍 Suggerimenti per il debug:"
echo "   1. Verificare che l'applicazione sia in esecuzione"
echo "   2. Controllare i log: kubectl logs deployment/<name>"
echo "   3. Verificare gli eventi: kubectl get events"
echo "   4. Testare manualmente: curl -v $URL/health"
echo ""

exit 1
