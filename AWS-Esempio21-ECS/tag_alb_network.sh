#!/bin/bash
# Tagga le interfacce di rete (ENI) e gli Elastic IP che AWS crea in automatico
# per i nodi di un ALB pubblico: non sono risorse Terraform e l'ALB non propaga
# i suoi tag. Variabili attese (passate dal provisioner local-exec di alb.tf):
#   AWS_REGION     es. eu-central-1
#   LB_ARN_SUFFIX  es. app/alnao-dev-terraform-esempio21-al/404fffe2e1737d1d
#   TAGS_ENI       tag delle ENI in formato JSON [{"Key":"...","Value":"..."}]
#   TAGS_EIP       tag degli EIP, stesso formato
set -euo pipefail

# Le ENI dei nodi hanno come descrizione "ELB <arn_suffix>"
ENIS=""
for i in $(seq 1 30); do
  ENIS=$(aws ec2 describe-network-interfaces --region "$AWS_REGION" \
    --filters "Name=description,Values=ELB $LB_ARN_SUFFIX" \
    --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)
  [ -n "$ENIS" ] && break
  echo "== ENI dell'ALB non ancora presenti, attendo ($i/30)"
  sleep 10
done
if [ -z "$ENIS" ]; then
  echo "Nessuna ENI trovata per $LB_ARN_SUFFIX" >&2
  exit 1
fi

echo "== Tag sulle ENI: $ENIS"
aws ec2 create-tags --region "$AWS_REGION" --resources $ENIS --tags "$TAGS_ENI"

# Gli EIP gestiti dal servizio (ServiceManaged = alb) associati a quelle ENI
EIPS=$(aws ec2 describe-addresses --region "$AWS_REGION" \
  --filters "Name=network-interface-id,Values=$(echo $ENIS | tr ' ' ',')" \
  --query 'Addresses[].AllocationId' --output text)
if [ -n "$EIPS" ]; then
  echo "== Tag sugli Elastic IP: $EIPS"
  aws ec2 create-tags --region "$AWS_REGION" --resources $EIPS --tags "$TAGS_EIP"
else
  echo "== Nessun Elastic IP associato alle ENI dell'ALB"
fi
