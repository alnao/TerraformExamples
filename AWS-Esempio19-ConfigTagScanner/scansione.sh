#!/bin/bash
# ============================================================
# Elenca le risorse NON conformi alla regola dei tag obbligatori,
# in TUTTE le regioni controllate, leggendo dal configuration aggregator.
#
#   ./scansione.sh                 # solo l'elenco delle risorse non conformi
#   ./scansione.sh -t              # con il dettaglio dei tag mancanti
#   ./scansione.sh -v              # forza una nuova valutazione in ogni regione e aspetta
#   ./scansione.sh -g eu-west-1    # una regione sola
#   ./scansione.sh -r nome-regola  # una regola sola (default: tutte, nativa e custom)
# ============================================================
set -uo pipefail

REGOLA=""
REGIONE=""
AGGREGATOR=""
DETTAGLIO=0
VALUTA=0

usage() {
  cat <<TXT
Uso: $0 [-r regola] [-a aggregator] [-g regione] [-t] [-v]

  -r  una sola config rule      (default: tutte quelle di terraform output config_rule_names)
  -a  nome dell'aggregator      (default: terraform output aggregator_name)
  -g  una sola regione          (default: tutte quelle di terraform output regions)
  -t  mostra quali tag mancano a ogni risorsa (una chiamata in piu' per risorsa)
  -v  lancia start-config-rules-evaluation in ogni regione e aspetta prima di leggere
TXT
}

while getopts "r:a:g:tv?" opzione; do
  case "$opzione" in
    r) REGOLA="$OPTARG" ;;
    a) AGGREGATOR="$OPTARG" ;;
    g) REGIONE="$OPTARG" ;;
    t) DETTAGLIO=1 ;;
    v) VALUTA=1 ;;
    *) usage; exit 1 ;;
  esac
done

# ---- Parametri dallo state di Terraform, se non passati a mano ----
if [ -n "$REGOLA" ]; then
  REGOLE="$REGOLA"
else
  REGOLE=$(terraform output -json config_rule_names 2>/dev/null | tr -d '[]"' | tr ',' ' ')
fi
if [ -z "$REGOLE" ]; then
  echo "Impossibile ricavare i nomi delle regole: passane una con -r" >&2
  exit 1
fi

if [ -z "$AGGREGATOR" ]; then
  AGGREGATOR=$(terraform output -raw aggregator_name 2>/dev/null)
  if [ -z "$AGGREGATOR" ]; then
    echo "Impossibile ricavare il nome dell'aggregator: passalo con -a" >&2
    exit 1
  fi
fi

HOME_REGION=$(terraform output -raw home_region 2>/dev/null)
if [ -n "$REGIONE" ]; then
  REGIONI="$REGIONE"
else
  REGIONI=$(terraform output -json regions 2>/dev/null | tr -d '[]"' | tr ',' ' ')
fi
if [ -z "$REGIONI" ]; then
  echo "Impossibile ricavare le regioni: passane una con -g" >&2
  exit 1
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# L'aggregator sta nella regione centrale: tutte le letture passano da li'
AWS=(aws)
if [ -n "$HOME_REGION" ]; then AWS+=(--region "$HOME_REGION"); fi

TAG_RICHIESTI=$(terraform output -json required_tag_keys 2>/dev/null | tr -d '[]"' || true)

echo "Regole:        $REGOLE"
echo "Aggregator:    $AGGREGATOR"
echo "Regioni:       $REGIONI"
[ -n "$TAG_RICHIESTI" ] && echo "Tag richiesti: $TAG_RICHIESTI"

if [ "$VALUTA" -eq 1 ]; then
  echo "Richiesta una nuova valutazione in ogni regione..."
  for regione in $REGIONI; do
    # shellcheck disable=SC2086
    aws --region "$regione" configservice start-config-rules-evaluation \
      --config-rule-names $REGOLE >/dev/null || echo "  $regione: richiesta fallita" >&2
  done
  # La valutazione non e' istantanea e l'aggregator copia i risultati con
  # qualche minuto di ritardo: si aspetta un po' di piu' della versione a regione singola
  sleep 60
fi

echo
echo "=== Risorse NON conformi ==="
TOTALE=0
for regione in $REGIONI; do
  # Le regole valutano tipi diversi: i risultati si sommano
  RISORSE=""
  for regola in $REGOLE; do
    parziale=$("${AWS[@]}" configservice get-aggregate-compliance-details-by-config-rule \
      --configuration-aggregator-name "$AGGREGATOR" \
      --config-rule-name "$regola" \
      --account-id "$ACCOUNT" \
      --aws-region "$regione" \
      --compliance-type NON_COMPLIANT \
      --query 'AggregateEvaluationResults[].EvaluationResultIdentifier.EvaluationResultQualifier.[ResourceType,ResourceId]' \
      --output text)
    [ -n "$parziale" ] && RISORSE="${RISORSE:+$RISORSE
}$parziale"
  done

  echo
  echo "--- $regione ---"
  if [ -z "$RISORSE" ]; then
    echo "  nessuna: tutte le risorse valutate hanno i tag richiesti (o l'aggregator non ha ancora dati)"
    continue
  fi

  printf "%-28s %s\n" "TIPO" "RISORSA"
  while read -r tipo risorsa; do
    [ -z "$tipo" ] && continue
    TOTALE=$((TOTALE + 1))
    printf "%-28s %s\n" "$tipo" "$risorsa"

    if [ "$DETTAGLIO" -eq 1 ]; then
      # I tag effettivi si leggono dall'elemento di configurazione registrato,
      # che sta nella regione della risorsa
      presenti=$(aws --region "$regione" configservice get-resource-config-history \
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
  done <<< "$RISORSE"
done

echo
echo "=== Riepilogo ==="
echo "Risorse non conformi in tutte le regioni: $TOTALE"
