#!/bin/sh
set -e

# Uninstall Kubernetes deployment.
# Usage: ./scripts/uninstall/k8s.sh <safe|clean|nuke>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
K8S_DIR="${ROOT_DIR}/k8s"
MODE="${1}"

if [ -z "${MODE}" ]; then
  echo "Usage: $0 <safe|clean|nuke>"
  exit 1
fi

# --- Backup first (safe and clean modes) ---

if [ "${MODE}" != "nuke" ]; then
  if kubectl get cronjob forgejo-backup -n forgejo > /dev/null 2>&1; then
    echo "Running backup before removal..."
    kubectl create job --from=cronjob/forgejo-backup pre-uninstall-backup -n forgejo 2>/dev/null || true
    kubectl wait --for=condition=complete job/pre-uninstall-backup -n forgejo --timeout=120s 2>/dev/null || true
    echo "Backup complete."

    if [ "${MODE}" = "safe" ]; then
      echo ""
      echo "NOTE: Backup data is stored in the forgejo-backups PVC."
      echo "To export backups before deletion, run:"
      echo "  kubectl cp forgejo/<backup-pod>:/backups ./backups-export"
    fi
  fi
fi

# --- Remove Forgejo namespace (removes everything in it) ---

echo "Removing Forgejo namespace..."
kubectl delete namespace forgejo --timeout=120s 2>/dev/null || true

# --- Remove cluster-wide resources ---

echo "Removing ClusterIssuer..."
kubectl delete clusterissuer letsencrypt-prod 2>/dev/null || true

echo "Removing Azure DNS secret..."
kubectl delete secret azure-dns-secret -n cert-manager 2>/dev/null || true

# --- Remove generated files (all modes) ---

echo "Removing generated files..."
rm -f "${K8S_DIR}/ingress.yml"
rm -f "${K8S_DIR}/cert-manager.yml"

# --- Remove secrets file (clean and nuke) ---

if [ "${MODE}" = "clean" ] || [ "${MODE}" = "nuke" ]; then
  echo "Removing secrets..."
  rm -f "${K8S_DIR}/secrets.yml"
fi

# --- Remove local data if exists (clean and nuke) ---

if [ "${MODE}" = "clean" ] || [ "${MODE}" = "nuke" ]; then
  # K3s local-path provisioner stores PVC data here
  K3S_LOCAL_PATH="/var/lib/rancher/k3s/storage"
  if [ -d "${K3S_LOCAL_PATH}" ]; then
    echo "Removing K3s local storage..."
    sudo rm -rf "${K3S_LOCAL_PATH}"/pvc-* 2>/dev/null || \
      echo "WARNING: Could not remove ${K3S_LOCAL_PATH} — may need sudo."
  fi
fi

echo ""
echo "Kubernetes deployment removed (${MODE} mode)."
