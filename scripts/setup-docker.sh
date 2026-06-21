#!/bin/sh
set -e

# Docker Compose deployment script.
# Handles both first-run (local-only) and full (exposed) deployment.
# Usage: ./scripts/setup-docker.sh <local|expose|update>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_DIR="${ROOT_DIR}/docker"
MODE="${1:-update}"

cd "${DOCKER_DIR}"

case "${MODE}" in
  local)
    # First run — deploy without external exposure
    echo "Starting Forgejo locally (no external access)..."

    # Use dev compose which exposes 3000 directly
    docker compose -f compose.yml -f compose.dev.yml up -d

    echo ""
    echo "Forgejo is starting on http://localhost:3000"
    echo "Complete the setup wizard in your browser."
    ;;

  expose)
    # After setup wizard — redeploy with full external access
    echo "Switching to production mode with TLS..."

    docker compose -f compose.yml -f compose.dev.yml down

    # Set ROOT_URL to production
    if grep -q "^ROOT_URL=http://localhost" .env 2>/dev/null; then
      HOSTNAME=$(grep "^HOSTNAME=" .env | cut -d= -f2)
      sed -i "s|^ROOT_URL=.*|ROOT_URL=https://${HOSTNAME}/|" .env
    fi

    docker compose -f compose.yml -f compose.prod.yml up -d

    echo ""
    echo "Forgejo is now exposed externally."
    ;;

  update)
    # Subsequent run — backup and update
    echo "Updating Docker deployment..."

    # Backup first
    if docker ps --format '{{.Names}}' | grep -q forgejo-backup; then
      echo "Backing up before update..."
      docker exec forgejo-backup sh /backup.sh
    fi

    # Pull latest images and recreate
    docker compose -f compose.yml -f compose.prod.yml pull
    docker compose -f compose.yml -f compose.prod.yml up -d

    echo ""
    echo "Update complete."
    ;;

  *)
    echo "Usage: $0 <local|expose|update>"
    exit 1
    ;;
esac

# Health check
echo "Waiting for Forgejo..."
sleep 5
if docker ps --format '{{.Names}}' | grep -q forgejo; then
  echo "Forgejo is running."
else
  echo "WARNING: Forgejo container not found. Check logs:"
  echo "  docker compose logs forgejo"
fi
