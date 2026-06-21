#!/bin/sh
set -e

# Forgejo Self-Hosted Git Server — Unified Deployment Script
#
# First run:  Installs prerequisites, configures secrets, deploys locally,
#             then exposes externally after setup wizard is complete.
# Subsequent: Backs up and updates the existing deployment.
#
# Usage: ./run.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml"
LOG_FILE="${SCRIPT_DIR}/run.log"

# --- Logging ---

exec > >(tee -a "${LOG_FILE}") 2>&1
echo ""
echo "=== run.sh started at $(date -Iseconds) ==="

# --- Helpers ---

detect_os() {
  OS=$(uname -s)
  ARCH=$(uname -m)

  case "${OS}" in
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID}"
      else
        DISTRO="unknown"
      fi
      PLATFORM="linux"
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      DISTRO="windows"
      PLATFORM="windows"
      ;;
    Darwin)
      DISTRO="macos"
      PLATFORM="macos"
      ;;
    *)
      echo "ERROR: Unsupported OS: ${OS}"
      exit 1
      ;;
  esac

  echo "Detected: ${DISTRO} (${ARCH}) on ${PLATFORM}"
}

read_config() {
  if [ -f "${CONFIG_FILE}" ]; then
    DEPLOYMENT=$(grep "^deployment:" "${CONFIG_FILE}" | awk '{print $2}')
    DNS_PROVIDER=$(grep "^dns_provider:" "${CONFIG_FILE}" | awk '{print $2}')
    SETUP_COMPLETE=$(grep "^setup_complete:" "${CONFIG_FILE}" | awk '{print $2}')
    EXPOSED=$(grep "^exposed:" "${CONFIG_FILE}" | awk '{print $2}')
    return 0
  fi
  return 1
}

write_config() {
  cat > "${CONFIG_FILE}" <<EOF
deployment: ${DEPLOYMENT}
dns_provider: ${DNS_PROVIDER}
setup_complete: ${SETUP_COMPLETE:-false}
exposed: ${EXPOSED:-false}
EOF
  chmod 600 "${CONFIG_FILE}"
}

print_access_instructions() {
  PORT="${1:-3000}"
  echo ""
  if [ -n "${SSH_CONNECTION}" ]; then
    HOST_IP=$(echo "${SSH_CONNECTION}" | awk '{print $3}')
    SSH_USER=$(whoami)
    echo "You are connected via SSH."
    echo "To access the setup wizard, run this on YOUR machine:"
    echo ""
    echo "  ssh -L ${PORT}:localhost:${PORT} ${SSH_USER}@${HOST_IP}"
    echo ""
    echo "Then open http://localhost:${PORT} in your browser."
  else
    echo "Open http://localhost:${PORT} in your browser."
  fi
}

list_dns_providers() {
  for f in "${SCRIPT_DIR}/scripts/dns/"*.sh; do
    basename "${f}" .sh
  done
}

# --- Main ---

echo ""
echo "==============================="
echo "  Forgejo Self-Hosted Git"
echo "==============================="
echo ""

detect_os

# --- Subsequent run ---

if read_config; then
  echo "Existing deployment found: ${DEPLOYMENT}"
  echo ""

  if [ "${SETUP_COMPLETE}" = "true" ] && [ "${EXPOSED}" = "true" ]; then
    # Full update
    echo "Running update..."
    "${SCRIPT_DIR}/scripts/setup-${DEPLOYMENT}.sh" update
    exit 0
  fi

  if [ "${SETUP_COMPLETE}" = "true" ] && [ "${EXPOSED}" != "true" ]; then
    # Setup done but not exposed yet
    echo "Setup complete — exposing externally..."
    "${SCRIPT_DIR}/scripts/setup-${DEPLOYMENT}.sh" expose
    EXPOSED=true
    write_config
    echo ""
    echo "Deployment complete."
    exit 0
  fi

  if [ "${SETUP_COMPLETE}" != "true" ]; then
    # Setup not complete — resume local deployment
    echo "Resuming local setup..."
    "${SCRIPT_DIR}/scripts/setup-${DEPLOYMENT}.sh" local &
    LOCAL_PID=$!
    print_access_instructions 3000
    echo ""
    printf "Press Enter when you have completed the setup wizard..."
    read -r _
    kill ${LOCAL_PID} 2>/dev/null || true
    wait ${LOCAL_PID} 2>/dev/null || true

    SETUP_COMPLETE=true
    write_config

    echo ""
    echo "Exposing externally..."
    "${SCRIPT_DIR}/scripts/setup-${DEPLOYMENT}.sh" expose
    EXPOSED=true
    write_config
    echo ""
    echo "Deployment complete."
    exit 0
  fi
fi

# --- First run ---

echo "First-time setup"
echo ""

# Choose deployment type
if [ "${PLATFORM}" = "windows" ]; then
  echo "Windows detected — using Docker Compose."
  DEPLOYMENT="docker"
else
  echo "Select deployment type:"
  echo "  1) Docker Compose"
  echo "  2) Kubernetes (K3s)"
  printf "Choice [1/2]: " && read -r DEPLOY_CHOICE
  case "${DEPLOY_CHOICE}" in
    2) DEPLOYMENT="k8s" ;;
    *) DEPLOYMENT="docker" ;;
  esac
fi

echo ""
echo "Deployment: ${DEPLOYMENT}"

# Install prerequisites (Linux only)
if [ "${PLATFORM}" = "linux" ]; then
  echo ""
  printf "Install prerequisites (docker/k3s/tea)? [Y/n]: " && read -r INSTALL_PREREQS
  case "${INSTALL_PREREQS}" in
    n|N) echo "Skipping prerequisite installation." ;;
    *) "${SCRIPT_DIR}/scripts/install-prerequisites.sh" "${DEPLOYMENT}" ;;
  esac
elif [ "${PLATFORM}" = "windows" ]; then
  echo ""
  echo "Prerequisites handled by run.cmd — continuing."
fi

# Choose DNS provider
echo ""
echo "Select DNS provider for TLS certificates:"
PROVIDERS=$(list_dns_providers)
i=1
for p in ${PROVIDERS}; do
  echo "  ${i}) ${p}"
  i=$((i + 1))
done
printf "Choice [1]: " && read -r DNS_CHOICE
DNS_PROVIDER=$(echo "${PROVIDERS}" | sed -n "${DNS_CHOICE:-1}p")
echo "DNS provider: ${DNS_PROVIDER}"

# Configure secrets
echo ""
"${SCRIPT_DIR}/scripts/configure-secrets.sh" "${DEPLOYMENT}" "${DNS_PROVIDER}"

# Save state
SETUP_COMPLETE=false
EXPOSED=false
write_config

# Deploy locally
echo ""
echo "Deploying locally (no external access yet)..."
"${SCRIPT_DIR}/scripts/setup-${DEPLOYMENT}.sh" local &
LOCAL_PID=$!

sleep 5
print_access_instructions 3000

echo ""
printf "Press Enter when you have completed the setup wizard..."
read -r _

kill ${LOCAL_PID} 2>/dev/null || true
wait ${LOCAL_PID} 2>/dev/null || true

SETUP_COMPLETE=true
write_config

# Expose externally
echo ""
echo "Exposing externally..."
"${SCRIPT_DIR}/scripts/setup-${DEPLOYMENT}.sh" expose

EXPOSED=true
write_config

echo ""
echo "==============================="
echo "  Deployment complete!"
echo "==============================="
echo ""
echo "Your Forgejo instance is ready."
echo ""
echo "Next steps:"
echo "  - Set up Tea CLI: see docs/git-client-setup.md"
echo "  - Configure backups: see docs/backup-and-restore.md"
echo ""
