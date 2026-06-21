#!/bin/bash
set -e

# Uninstall prerequisites (Docker/K3s/Tea/cert-manager).
# Interactive — asks what to remove.
# Usage: ./scripts/uninstall/prerequisites.sh

OS=$(uname -s)

cmd_exists() {
  command -v "$1" > /dev/null 2>&1
}

detect_platform() {
  case "${OS}" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) PLATFORM="windows" ;;
    Linux) PLATFORM="linux" ;;
    *) PLATFORM="unknown" ;;
  esac
}

detect_platform

echo ""
echo "=== Uninstall Prerequisites ==="
echo ""

# --- Tea CLI ---

if cmd_exists tea; then
  printf "Uninstall Tea CLI? [y/N]: " && read -er REMOVE_TEA
  case "${REMOVE_TEA}" in
    y|Y)
      if [ "${PLATFORM}" = "linux" ]; then
        sudo rm -f /usr/local/bin/tea 2>/dev/null || rm -f /usr/local/bin/tea
        echo "Tea CLI removed."
      elif [ "${PLATFORM}" = "windows" ]; then
        rm -f "${USERPROFILE}/AppData/Local/Microsoft/WindowsApps/tea.exe" 2>/dev/null || true
        echo "Tea CLI removed."
      fi
      ;;
  esac
fi

# --- cert-manager (K8s only) ---

if cmd_exists kubectl && kubectl get namespace cert-manager > /dev/null 2>&1; then
  printf "Uninstall cert-manager? [y/N]: " && read -er REMOVE_CERTMGR
  case "${REMOVE_CERTMGR}" in
    y|Y)
      echo "Removing cert-manager..."
      kubectl delete namespace cert-manager --timeout=120s 2>/dev/null || true
      echo "cert-manager removed."
      ;;
  esac
fi

# --- K3s ---

if [ "${PLATFORM}" = "linux" ] && [ -f /usr/local/bin/k3s-uninstall.sh ]; then
  printf "Uninstall K3s? This removes ALL Kubernetes data. [y/N]: " && read -er REMOVE_K3S
  case "${REMOVE_K3S}" in
    y|Y)
      echo "Uninstalling K3s..."
      /usr/local/bin/k3s-uninstall.sh
      echo "K3s removed."
      ;;
  esac
fi

# --- Docker ---

if cmd_exists docker; then
  printf "Uninstall Docker? [y/N]: " && read -er REMOVE_DOCKER
  case "${REMOVE_DOCKER}" in
    y|Y)
      if [ "${PLATFORM}" = "linux" ]; then
        if [ -f /etc/os-release ]; then
          . /etc/os-release
          DISTRO="${ID}"
        fi

        echo "Removing Docker..."
        case "${DISTRO}" in
          debian|ubuntu|raspbian)
            sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
            sudo apt-get autoremove -y
            ;;
          centos|rhel|fedora|rocky|alma)
            sudo yum remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
            ;;
          alpine)
            sudo apk del docker docker-cli docker-compose 2>/dev/null || true
            ;;
          *)
            echo "WARNING: Unknown distro. Remove Docker manually."
            ;;
        esac

        # Remove Docker data
        printf "Also remove all Docker data (/var/lib/docker)? [y/N]: " && read -er REMOVE_DOCKER_DATA
        case "${REMOVE_DOCKER_DATA}" in
          y|Y) sudo rm -rf /var/lib/docker /var/lib/containerd ;;
        esac

        echo "Docker removed."

      elif [ "${PLATFORM}" = "windows" ]; then
        echo ""
        echo "To uninstall Docker Desktop on Windows:"
        echo "  1. Open Settings > Apps > Installed Apps"
        echo "  2. Find 'Docker Desktop'"
        echo "  3. Click Uninstall"
        echo ""
      fi
      ;;
  esac
fi

echo ""
echo "Prerequisite cleanup complete."
