#!/bin/bash
# User data dell'esempio 20: Docker + postgres + pathsgames (immagine da ECR).
# File processato da templatefile(): le variabili bash sono scritte senza graffe
# oppure con $${...} per non essere confuse con quelle di Terraform.
# niente "set -x": stamperebbe i segreti nel log e nella console output
set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

REGION="${region}"

# ---------- Docker ----------
dnf install -y docker
systemctl enable --now docker

# ---------- Segreti da SSM Parameter Store ----------
get_secret() {
  aws ssm get-parameter --region "$REGION" --with-decryption \
    --name "$1" --query Parameter.Value --output text
}
DB_PASSWORD=$(get_secret "${ssm_db_password}")
JWT_SECRET=$(get_secret "${ssm_jwt_secret}")
BANNED_SUBJECT_PEPPER=$(get_secret "${ssm_banned_pepper}")

# ---------- Login su ECR e pull dell'immagine ----------
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${registry}"
docker pull "${image_uri}"

# ---------- Rete e log ----------
docker network create pathsgames || true
LOG_OPTS="--log-driver=awslogs --log-opt awslogs-region=$REGION --log-opt awslogs-group=${log_group_name}"

# ---------- PostgreSQL ----------
mkdir -p /opt/pathsgames/pgdata
docker run -d --name pathsgames-db --network pathsgames --restart unless-stopped \
  $LOG_OPTS --log-opt awslogs-stream=postgres \
  -e POSTGRES_DB="${db_name}" \
  -e POSTGRES_USER="${db_username}" \
  -e POSTGRES_PASSWORD="$DB_PASSWORD" \
  -v /opt/pathsgames/pgdata:/var/lib/postgresql/data \
  "${postgres_image}"

# Attende che il database accetti connessioni prima di avviare l'applicazione
for i in $(seq 1 30); do
  docker exec pathsgames-db pg_isready -U "${db_username}" -d "${db_name}" && break
  sleep 2
done

# ---------- Paths Games ----------
# Viene pubblicata solo la porta 8042 (API pubblica); la 8044 (admin) resta interna.
docker run -d --name pathsgames --network pathsgames --restart unless-stopped \
  $LOG_OPTS --log-opt awslogs-stream=pathsgames \
  -p ${host_port}:8042 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e ENVIRONMENT="${environment_name}" \
  -e DB_HOST=pathsgames-db \
  -e DB_PORT=5432 \
  -e DB_NAME="${db_name}" \
  -e DB_USERNAME="${db_username}" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e JWT_SECRET="$JWT_SECRET" \
  -e BANNED_SUBJECT_PEPPER="$BANNED_SUBJECT_PEPPER" \
  "${image_uri}"
