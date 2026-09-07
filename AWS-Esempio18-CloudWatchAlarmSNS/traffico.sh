#!/bin/bash
# ============================================================
# Generatore di traffico per la demo.
#
# Chiama /ok e /ko un certo numero di volte, cosi' l'allarme si puo' far
# scattare a comando senza lanciare curl a mano durante una presentazione.
#
#   ./traffico.sh                      # host preso da terraform output
#   ./traffico.sh -e 20 -o 5           # 20 errori e 5 risposte buone
#   ./traffico.sh -h 1.2.3.4 -e 30 -p 0.2
#   ./traffico.sh -m privata           # prova 401 e 403 sull'area protetta
# ============================================================
set -uo pipefail

HOST=""
ERRORI=10
OK=5
PAUSA=0.5
MODO="ko"

usage() {
  cat <<TXT
Uso: $0 [-h host] [-e n_errori] [-o n_ok] [-p pausa_secondi] [-m ko|privata]

  -h  IP o dns del web server (default: terraform output instance_public_ip)
  -e  numero di chiamate che devono fallire        (default: $ERRORI)
  -o  numero di chiamate che devono riuscire       (default: $OK)
  -p  pausa in secondi fra una chiamata e l'altra  (default: $PAUSA)
  -m  ko      = usa /ko, l'errore simulato con Redirect
      privata = usa /privata, errori 401 e 403 veri della Basic Auth
TXT
}

while getopts "h:e:o:p:m:?" opzione; do
  case "$opzione" in
    h) HOST="$OPTARG" ;;
    e) ERRORI="$OPTARG" ;;
    o) OK="$OPTARG" ;;
    p) PAUSA="$OPTARG" ;;
    m) MODO="$OPTARG" ;;
    *) usage; exit 1 ;;
  esac
done

if [ -z "$HOST" ]; then
  HOST=$(terraform output -raw instance_public_ip 2>/dev/null)
  if [ -z "$HOST" ]; then
    echo "Impossibile ricavare l'host: passalo con -h" >&2
    exit 1
  fi
fi

BASE="http://$HOST"
echo "Web server: $BASE   modo: $MODO"

# Restituisce solo il codice HTTP della risposta
chiama() {
  curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$@"
}

echo "--- $OK chiamate che devono rispondere 200 ---"
for i in $(seq 1 "$OK"); do
  codice=$(chiama "$BASE/ok/")
  echo "  ok  $i/$OK -> $codice"
  sleep "$PAUSA"
done

echo "--- $ERRORI chiamate che devono fallire ---"
for i in $(seq 1 "$ERRORI"); do
  if [ "$MODO" = "privata" ]; then
    # Alternanza voluta: senza credenziali -> 401, con utente
    # autenticato ma non autorizzato -> 403. Sono due cose diverse.
    if [ $((i % 2)) -eq 0 ]; then
      codice=$(chiama "$BASE/privata/")
      etichetta="senza credenziali"
    else
      codice=$(chiama -u "ospite:ospite18" "$BASE/privata/")
      etichetta="utente non autorizzato"
    fi
    echo "  ko  $i/$ERRORI -> $codice ($etichetta)"
  else
    codice=$(chiama "$BASE/ko")
    echo "  ko  $i/$ERRORI -> $codice"
  fi
  sleep "$PAUSA"
done

cat <<TXT

Fatto. Adesso servono un paio di minuti:
  - il CloudWatch Agent spedisce il log
  - il metric filter aggiorna la metrica
  - l'allarme valuta il periodo e pubblica su SNS
  - la Lambda scrive la riga su DynamoDB

Da guardare:
  aws cloudwatch describe-alarms --alarm-name-prefix "\$(terraform output -raw alarm_name)" \\
    --query 'MetricAlarms[].[AlarmName,StateValue]' --output table
  $BASE/allarmi/
TXT
