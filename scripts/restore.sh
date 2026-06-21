#!/bin/sh
set -e

# Usage: ./scripts/restore.sh [backup_folder]
# Example: ./scripts/restore.sh 20260620_030000
# If no argument given, uses the latest backup.
#
# Works with both Docker Compose and Kubernetes.
# Docker:  docker compose run --rm backup sh /scripts/restore.sh
# K8s:     kubectl apply -f k8s/restore-job.yml

BACKUP_NAME="${1}"

if [ -z "${BACKUP_NAME}" ]; then
  BACKUP_NAME=$(ls -1 /backups | sort -r | head -1)
  echo "No backup specified, using latest: ${BACKUP_NAME}"
fi

BACKUP_DIR="/backups/${BACKUP_NAME}"

if [ ! -d "${BACKUP_DIR}" ]; then
  echo "ERROR: Backup not found: ${BACKUP_DIR}"
  exit 1
fi

echo ""
echo "=== RESTORE FROM: ${BACKUP_DIR} ==="
cat "${BACKUP_DIR}/backup.info"
echo ""

# Only wait for confirmation in interactive mode
if [ -t 0 ]; then
  echo "This will OVERWRITE the current database and Forgejo data."
  echo "Press Ctrl+C within 10 seconds to cancel..."
  sleep 10
fi

# 1. Restore database
echo "[$(date)] Restoring database..."
gunzip -c "${BACKUP_DIR}/database.sql.gz" \
  | psql -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --quiet

# 2. Restore Forgejo data
echo "[$(date)] Restoring Forgejo data..."
cd /data/forgejo
tar xzf "${BACKUP_DIR}/forgejo-data.tar.gz"

echo ""
echo "[$(date)] Restore complete. Restart Forgejo to apply."
