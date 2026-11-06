#!/bin/bash
# Copia un'immagine da Docker Hub al repository ECR creato da Terraform.
# Variabili attese (passate dal provisioner local-exec di ecr.tf):
#   SOURCE_IMAGE   es. pathsgames/pathsgames:1.12.0
#   TARGET_IMAGE   es. 123456789012.dkr.ecr.eu-central-1.amazonaws.com/repo:1.12.0
#   REGISTRY       es. 123456789012.dkr.ecr.eu-central-1.amazonaws.com
#   AWS_REGION     es. eu-central-1
#   IMAGE_PLATFORM es. linux/amd64
set -euo pipefail

echo "== Pull di ${SOURCE_IMAGE} (${IMAGE_PLATFORM})"
docker pull --platform "${IMAGE_PLATFORM}" "${SOURCE_IMAGE}"

echo "== Login su ${REGISTRY}"
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo "== Push di ${TARGET_IMAGE}"
docker tag "${SOURCE_IMAGE}" "${TARGET_IMAGE}"
docker push "${TARGET_IMAGE}"
