#!/bin/sh
set -e

# Installs prerequisites for Docker or Kubernetes deployment.
# Detects OS, architecture, and package manager automatically.
# Usage: ./scripts/install-prerequisites.sh <docker|k8s>

DEPLOYMENT="${1}"

if [ -z "${DEPLOYMENT}" ]; then
  echo "Usage: $0 <docker|k8s>"
  exit 1
fi

# --- Detect environment ---

ARCH=$(uname -m)
OS=$(uname -s)

if [ "${OS}" != "Linux" ]; then
  echo "ERROR: Only Linux is supported. Detected: ${OS}"
  exit 1
fi

if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO="${ID}"
else
  echo "ERROR: Cannot detect Linux distribution."
  exit 1
fi

case "${DISTRO}" in
  debian|ubuntu|raspbian) PKG_MGR="apt" ;;
  alpine) PKG_MGR="apk" ;;
  centos|rhel|fedora|rocky|alma) PKG_MGR="yum" ;;
  *) echo "WARNING: Unknown distro '${DISTRO}', assuming apt."; PKG_MGR="apt" ;;
esac

echo "Detected: ${DISTRO} (${ARCH}) using ${PKG_MGR}"

# --- Helper ---

cmd_exists() {
  command -v "$1" > /dev/null 2>&1
}

# --- Install Docker ---

install_docker() {
  if cmd_exists docker; then
    echo "Docker already installed: $(docker --version)"
    return
  fi

  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh

  # Add current user to docker group
  if [ "$(id -u)" -ne 0 ]; then
    sudo usermod -aG docker "$(whoami)"
    echo "NOTE: Log out and back in for Docker group to take effect."
  fi
}

# --- Install K3s ---

install_k3s() {
  if cmd_exists kubectl && kubectl get nodes > /dev/null 2>&1; then
    echo "K3s already installed: $(kubectl version --short 2>/dev/null || echo 'running')"
    return
  fi

  echo "Installing K3s..."
  curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

  # Wait for K3s to be ready
  echo "Waiting for K3s..."
  sleep 10
  kubectl wait --for=condition=Ready node --all --timeout=120s
}

# --- Install Tea CLI ---

install_tea() {
  if cmd_exists tea; then
    echo "Tea CLI already installed."
    return
  fi

  echo "Installing Tea CLI..."

  case "${ARCH}" in
    x86_64|amd64) TEA_ARCH="amd64" ;;
    aarch64|arm64) TEA_ARCH="arm64" ;;
    armv7l|armhf) TEA_ARCH="armv6" ;;
    *) echo "WARNING: Unknown arch '${ARCH}' for Tea CLI, trying amd64."; TEA_ARCH="amd64" ;;
  esac

  TEA_URL="https://gitea.com/gitea/tea/releases/download/v0.14.1/tea-0.14.1-linux-${TEA_ARCH}"
  TEA_BIN="/usr/local/bin/tea"

  if [ "$(id -u)" -eq 0 ]; then
    curl -sL -o "${TEA_BIN}" "${TEA_URL}"
    chmod +x "${TEA_BIN}"
  else
    sudo curl -sL -o "${TEA_BIN}" "${TEA_URL}"
    sudo chmod +x "${TEA_BIN}"
  fi

  echo "Tea CLI installed."
}

# --- Main ---

case "${DEPLOYMENT}" in
  docker)
    install_docker
    install_tea
    ;;
  k8s)
    install_k3s
    install_tea
    ;;
  *)
    echo "ERROR: Unknown deployment type '${DEPLOYMENT}'. Use 'docker' or 'k8s'."
    exit 1
    ;;
esac

echo ""
echo "Prerequisites installed."
