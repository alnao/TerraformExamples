#!/bin/bash
# ============================================================
# Elenca le risorse NON conformi alla regola dei tag obbligatori.
#
#   ./scansione.sh                 # solo l'elenco delle risorse non conformi
#   ./scansione.sh -t              # con il dettaglio dei tag mancanti
#   ./scansione.sh -v              # forza una nuova valutazione e aspetta
#   ./scansione.sh -r nome-regola  # su una regola diversa da quella di default
# ============================================================
set -uo pipefail

REGOLA=""
REGIONE=""
DETTAGLIO=0
VALUTA=0

usage() {
  cat <<TXT
Uso: $0 [-r regola] [-g regione] [-t] [-v]

  -r  nome della config rule    (default: terraform output config_rule_name)
  -g  regione AWS               (default: quella della AWS CLI)
  -t  mostra quali tag mancano a ogni risorsa (una chiamata in piu' per risorsa)
  -v  lancia start-config-rules-evaluation e aspetta prima di leggere
TXT
}

while getopts "r:g:tv?" opzione; do
  case "$opzione" in
    r) REGOLA="$OPTARG" ;;
    g) REGIONE="$OPTARG" ;;
    t) DETTAGLIO=1 ;;
    v) VALUTA=1 ;;
    *) usage; exit 1 ;;
  esac
done

if [ -z "$REGOLA" ]; then
  REGOLA=$(terraform output -raw config_rule_name 2>/dev/null)
  if [ -z "$REGOLA" ]; then
    echo "Impossibile ricavare il nome della regola: passalo con -r" >&2
    exit 1
  fi
fi

AWS=(aws)
if [ -n "$REGIONE" ]; then AWS+=(--region "$REGIONE"); fi

TAG_RICHIESTI=$(terraform output -json required_tag_keys 2>/dev/null | tr -d '[]"' || true)

echo "Regola:        $REGOLA"
[ -n "$TAG_RICHIESTI" ] && echo "Tag richiesti: $TAG_RICHIESTI"

if [ "$VALUTA" -eq 1 ]; then
  echo "Richiesta una nuova valutazione..."
  "${AWS[@]}" configservice start-config-rules-evaluation --config-rule-names "$REGOLA" >/dev/null
  # La valutazione non e' istantanea: Config rivaluta le risorse in background
  sleep 30
fi

echo
echo "=== Riepilogo ==="
"${AWS[@]}" configservice describe-compliance-by-config-rule \
  --config-rule-names "$REGOLA" \
  --query 'ComplianceByConfigRules[0].Compliance.ComplianceContributorCount.CappedCount' \
  --output text | while read -r conteggio; do
    if [ "$conteggio" = "None" ] || [ -z "$conteggio" ]; then
      echo "Nessuna risorsa non conforme (o valutazione non ancora eseguita)."
    else
      echo "Risorse non conformi: $conteggio"
    fi
  done

echo
echo "=== Risorse NON conformi ==="
RISORSE=$("${AWS[@]}" configservice get-compliance-details-by-config-rule \
  --config-rule-name "$REGOLA" \
  --compliance-types NON_COMPLIANT \
  --query 'EvaluationResults[].EvaluationResultIdentifier.EvaluationResultQualifier.[ResourceType,ResourceId]' \
  --output text)

if [ -z "$RISORSE" ]; then
  echo "  nessuna: tutte le risorse valutate hanno i tag richiesti"
  exit 0
fi

printf "%-28s %s\n" "TIPO" "RISORSA"
echo "$RISORSE" | while read -r tipo risorsa; do
  printf "%-28s %s\n" "$tipo" "$risorsa"

  if [ "$DETTAGLIO" -eq 1 ]; then
    # I tag effettivi si leggono dall'elemento di configurazione registrato
    presenti=$("${AWS[@]}" configservice get-resource-config-history \
      --resource-type "$tipo" --resource-id "$risorsa" --limit 1 \
      --query 'configurationItems[0].tags' --output json 2>/dev/null)
    mancanti=""
    for tag in $(echo "$TAG_RICHIESTI" | tr ',' ' '); do
      if ! echo "$presenti" | grep -q "\"$tag\""; then
        mancanti="$mancanti $tag"
      fi
    done
    if [ -n "$mancanti" ]; then
      echo "      tag mancanti:$mancanti"
    else
      echo "      tag presenti ma con valore non ammesso"
    fi
  fi
done
