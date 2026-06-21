#!/bin/bash
set -e

# Forgejo Self-Hosted Git Server — Uninstall Script
#
# Modes:
#   Safe  — backup first, remove deployment, keep backups + config
#   Clean — backup first, remove everything including data
#   Nuke  — no backup, remove absolutely everything
#
# Usage: ./uninstall.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml"

# --- Detect deployment type ---

DEPLOYMENT=""

if [ -f "${CONFIG_FILE}" ]; then
  DEPLOYMENT=$(grep "^deployment:" "${CONFIG_FILE}" | awk '{print $2}')
fi

if [ -z "${DEPLOYMENT}" ]; then
  echo ""
  echo "No config.yml found. What deployment type do you want to uninstall?"
  echo "  1) Docker Compose"
  echo "  2) Kubernetes (K3s)"
  printf "Choice [1/2]: " && read -er DEPLOY_CHOICE
  case "${DEPLOY_CHOICE}" in
    2) DEPLOYMENT="k8s" ;;
    *) DEPLOYMENT="docker" ;;
  esac
fi

echo ""
echo "==============================="
echo "  Forgejo Uninstall"
echo "==============================="
echo ""
echo "Deployment type: ${DEPLOYMENT}"
echo ""

# --- Show what exists ---

echo "Current state:"
if [ "${DEPLOYMENT}" = "docker" ]; then
  docker ps --format '  Container: {{.Names}} ({{.Status}})' 2>/dev/null || echo "  No Docker containers running"
  [ -d "${SCRIPT_DIR}/docker/data" ] && echo "  Data directory: exists" || echo "  Data directory: none"
  [ -d "${SCRIPT_DIR}/docker/backups" ] && echo "  Backups: exists" || echo "  Backups: none"
  [ -f "${SCRIPT_DIR}/docker/.env" ] && echo "  Config (.env): exists" || echo "  Config (.env): none"
else
  kubectl get pods -n forgejo 2>/dev/null || echo "  No Forgejo pods running"
  kubectl get pvc -n forgejo 2>/dev/null || echo "  No PVCs"
  [ -f "${SCRIPT_DIR}/k8s/secrets.yml" ] && echo "  Secrets file: exists" || echo "  Secrets file: none"
fi

# --- Choose mode ---

echo ""
echo "Uninstall mode:"
echo "  1) Safe  — backup first, remove deployment, keep backups + config"
echo "  2) Clean — backup first, remove deployment + data + config"
echo "  3) Nuke  — no backup, remove absolutely everything"
echo ""
printf "Choice [1/2/3]: " && read -er MODE_CHOICE

case "${MODE_CHOICE}" in
  2) MODE="clean" ;;
  3) MODE="nuke" ;;
  *) MODE="safe" ;;
esac

# --- Confirm ---

echo ""
if [ "${MODE}" = "nuke" ]; then
  echo "WARNING: This will permanently delete ALL data, backups, and config."
  echo "         There is NO recovery after this."
  echo ""
  printf "Type 'NUKE' to confirm: " && read -er CONFIRM
  if [ "${CONFIRM}" != "NUKE" ]; then
    echo "Aborted."
    exit 1
  fi
else
  printf "Proceed with ${MODE} uninstall? [y/N]: " && read -er CONFIRM
  case "${CONFIRM}" in
    y|Y) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# --- Execute ---

echo ""
"${SCRIPT_DIR}/scripts/uninstall/${DEPLOYMENT}.sh" "${MODE}"

# --- Clean up config ---

if [ "${MODE}" = "clean" ] || [ "${MODE}" = "nuke" ]; then
  echo "Removing config.yml..."
  rm -f "${CONFIG_FILE}"
fi

# --- Ask about prerequisites ---

echo ""
printf "Also uninstall prerequisites (Docker/K3s/Tea CLI)? [y/N]: " && read -er REMOVE_PREREQS
case "${REMOVE_PREREQS}" in
  y|Y) "${SCRIPT_DIR}/scripts/uninstall/prerequisites.sh" ;;
esac

echo ""
echo "==============================="
echo "  Uninstall complete (${MODE})"
echo "==============================="
echo ""

if [ "${MODE}" = "safe" ]; then
  echo "Backups and config files were preserved."
  echo "To reinstall: ./run.sh"
fi
