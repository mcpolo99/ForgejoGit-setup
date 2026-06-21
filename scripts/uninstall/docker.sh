#!/bin/sh
set -e

# Uninstall Docker Compose deployment.
# Usage: ./scripts/uninstall/docker.sh <safe|clean|nuke>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="${ROOT_DIR}/docker"
MODE="${1}"

if [ -z "${MODE}" ]; then
  echo "Usage: $0 <safe|clean|nuke>"
  exit 1
fi

cd "${DOCKER_DIR}"

# --- Backup first (safe and clean modes) ---

if [ "${MODE}" != "nuke" ]; then
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q forgejo-backup; then
    echo "Running backup before removal..."
    docker exec forgejo-backup sh /backup.sh
    echo "Backup complete."
  fi
fi

# --- Stop and remove containers ---

echo "Stopping containers..."
if [ "${MODE}" = "safe" ]; then
  docker compose -f compose.yml -f compose.prod.yml down 2>/dev/null || \
  docker compose -f compose.yml -f compose.dev.yml down 2>/dev/null || true
else
  docker compose -f compose.yml -f compose.prod.yml down --volumes --rmi all 2>/dev/null || \
  docker compose -f compose.yml -f compose.dev.yml down --volumes --rmi all 2>/dev/null || true
fi

# --- Remove generated config files (all modes) ---

echo "Removing generated config files..."
rm -f traefik/traefik.yml traefik/dynamic.yml traefik/acme.json

# --- Remove data (clean and nuke) ---

if [ "${MODE}" = "clean" ] || [ "${MODE}" = "nuke" ]; then
  echo "Removing data..."
  rm -rf "${DOCKER_DIR}/data"
  rm -f "${DOCKER_DIR}/.env"
fi

# --- Remove backups (nuke only) ---

if [ "${MODE}" = "nuke" ]; then
  echo "Removing backups..."
  rm -rf "${DOCKER_DIR}/backups"
fi

# --- Remove Docker network ---

docker network rm proxy 2>/dev/null || true

echo ""
echo "Docker deployment removed (${MODE} mode)."
