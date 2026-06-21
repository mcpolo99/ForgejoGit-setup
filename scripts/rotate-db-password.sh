#!/bin/sh
set -e

# Rotates the Postgres password safely.
# Works with both Docker Compose and Kubernetes.
#
# Usage:
#   ./scripts/rotate-db-password.sh NEW_PASSWORD
#
# Steps:
#   1. Triggers a backup
#   2. Changes the password in Postgres
#   3. Prints next steps (update secrets, restart Forgejo)

NEW_PASSWORD="${1}"

if [ -z "${NEW_PASSWORD}" ]; then
  echo "Usage: $0 NEW_PASSWORD"
  echo ""
  echo "Generate a strong password with: openssl rand -hex 24"
  exit 1
fi

# Detect environment
if command -v kubectl > /dev/null 2>&1 && kubectl get namespace forgejo > /dev/null 2>&1; then
  ENV="k8s"
  POSTGRES_USER=$(kubectl get secret forgejo-secrets -n forgejo -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)
  POSTGRES_DB=$(kubectl get secret forgejo-secrets -n forgejo -o jsonpath='{.data.POSTGRES_DB}' | base64 -d)
elif command -v docker > /dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q forgejo-db; then
  ENV="docker"
  POSTGRES_USER=$(docker exec forgejo-db printenv POSTGRES_USER)
  POSTGRES_DB=$(docker exec forgejo-db printenv POSTGRES_DB)
else
  echo "ERROR: No running Forgejo found (neither K8s nor Docker)."
  exit 1
fi

echo "Environment: ${ENV}"
echo "Database:    ${POSTGRES_DB}"
echo "User:        ${POSTGRES_USER}"
echo ""

# 1. Backup first
echo "[$(date)] Triggering backup before password change..."
if [ "${ENV}" = "k8s" ]; then
  kubectl create job --from=cronjob/forgejo-backup pre-rotate-backup -n forgejo
  echo "Waiting for backup to complete..."
  kubectl wait --for=condition=complete job/pre-rotate-backup -n forgejo --timeout=120s
  kubectl delete job pre-rotate-backup -n forgejo
elif [ "${ENV}" = "docker" ]; then
  docker exec forgejo-backup sh /backup.sh
fi
echo "[$(date)] Backup complete."

# 2. Change password in Postgres
echo "[$(date)] Changing Postgres password..."
if [ "${ENV}" = "k8s" ]; then
  kubectl exec -n forgejo deploy/postgres -- \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
    -c "ALTER USER ${POSTGRES_USER} WITH PASSWORD '${NEW_PASSWORD}';"
elif [ "${ENV}" = "docker" ]; then
  docker exec forgejo-db \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
    -c "ALTER USER ${POSTGRES_USER} WITH PASSWORD '${NEW_PASSWORD}';"
fi
echo "[$(date)] Password changed in Postgres."

# 3. Next steps
echo ""
echo "=== Password changed successfully ==="
echo ""
if [ "${ENV}" = "k8s" ]; then
  echo "Now update secrets.yml with the new password and run:"
  echo "  kubectl apply -f k8s/secrets.yml"
  echo "  kubectl rollout restart deploy/forgejo -n forgejo"
elif [ "${ENV}" = "docker" ]; then
  echo "Now update .env with the new password and run:"
  echo "  docker compose restart forgejo"
fi
