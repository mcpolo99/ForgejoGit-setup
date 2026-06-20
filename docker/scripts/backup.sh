#!/bin/sh
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/${TIMESTAMP}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-30}"

echo "[$(date)] Starting backup..."

mkdir -p "${BACKUP_DIR}"

# 1. Dump Postgres
echo "[$(date)] Dumping database..."
pg_dump -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
  --clean --if-exists --no-owner \
  | gzip > "${BACKUP_DIR}/database.sql.gz"

# 2. Backup Forgejo data (config, repos, avatars, LFS, etc)
echo "[$(date)] Backing up Forgejo data..."
tar czf "${BACKUP_DIR}/forgejo-data.tar.gz" \
  -C /data/forgejo \
  --exclude='log' \
  --exclude='sessions' \
  --exclude='indexers' \
  .

# 3. Write metadata for easy restore
cat > "${BACKUP_DIR}/backup.info" <<EOF
timestamp=${TIMESTAMP}
date=$(date -Iseconds)
postgres_db=${POSTGRES_DB}
EOF

echo "[$(date)] Backup saved to ${BACKUP_DIR}"

# 4. Delete backups older than KEEP_DAYS
echo "[$(date)] Cleaning backups older than ${KEEP_DAYS} days..."
find /backups -maxdepth 1 -type d -mtime +${KEEP_DAYS} -not -path /backups \
  -exec rm -rf {} \;

echo "[$(date)] Backup complete."
