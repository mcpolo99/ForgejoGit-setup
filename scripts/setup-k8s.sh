#!/bin/sh
set -e

# Kubernetes deployment script.
# Handles both first-run (local-only) and full (exposed) deployment.
# Usage: ./scripts/setup-k8s.sh <local|expose|update>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${ROOT_DIR}/k8s"
MODE="${1:-update}"
SECRETS_FILE="${K8S_DIR}/secrets.yml"

if [ ! -f "${SECRETS_FILE}" ]; then
  echo "ERROR: ${SECRETS_FILE} not found."
  exit 1
fi

# --- Parse values from secrets.yml ---

get_secret() {
  grep "^  $1:" "${SECRETS_FILE}" | sed "s/^  $1: *//" | tr -d '"' | tr -d "'"
}

HOSTNAME=$(get_secret HOSTNAME)
SSH_PORT=$(get_secret SSH_PORT)
POSTGRES_DB=$(get_secret POSTGRES_DB)
POSTGRES_USER=$(get_secret POSTGRES_USER)
POSTGRES_PASSWORD=$(get_secret POSTGRES_PASSWORD)
ACME_EMAIL=$(get_secret ACME_EMAIL)
AZURE_CLIENT_ID=$(get_secret AZURE_CLIENT_ID)
AZURE_CLIENT_SECRET=$(get_secret AZURE_CLIENT_SECRET)
AZURE_TENANT_ID=$(get_secret AZURE_TENANT_ID)
AZURE_SUBSCRIPTION_ID=$(get_secret AZURE_SUBSCRIPTION_ID)
AZURE_RESOURCE_GROUP=$(get_secret AZURE_RESOURCE_GROUP)
AZURE_ZONE_NAME=$(get_secret AZURE_ZONE_NAME)

cd "${K8S_DIR}"

# --- Generate manifests from samples ---

generate_manifests() {
  echo "Generating ingress.yml from sample..."
  cp ingress.sample.yml ingress.yml
  sed -i "s/__HOSTNAME__/${HOSTNAME}/g" ingress.yml
  sed -i "s/__SSH_PORT__/${SSH_PORT}/g" ingress.yml

  echo "Generating cert-manager.yml from sample..."
  cp cert-manager.sample.yml cert-manager.yml
  sed -i "s/__ACME_EMAIL__/${ACME_EMAIL}/g" cert-manager.yml
  sed -i "s|__AZURE_CLIENT_ID__|${AZURE_CLIENT_ID}|g" cert-manager.yml
  sed -i "s|__AZURE_SUBSCRIPTION_ID__|${AZURE_SUBSCRIPTION_ID}|g" cert-manager.yml
  sed -i "s|__AZURE_TENANT_ID__|${AZURE_TENANT_ID}|g" cert-manager.yml
  sed -i "s/__AZURE_RESOURCE_GROUP__/${AZURE_RESOURCE_GROUP}/g" cert-manager.yml
  sed -i "s/__AZURE_ZONE_NAME__/${AZURE_ZONE_NAME}/g" cert-manager.yml
}

# --- Apply core resources (no external exposure) ---

apply_core() {
  echo "Creating namespace..."
  kubectl apply -f namespace.yml

  echo "Applying secrets..."
  kubectl apply -f "${SECRETS_FILE}"

  echo "Creating forgejo-config..."
  kubectl create configmap forgejo-config \
    --namespace forgejo \
    --from-literal=HOSTNAME="${HOSTNAME}" \
    --from-literal=ROOT_URL="https://${HOSTNAME}/" \
    --from-literal=SSH_PORT="${SSH_PORT}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Creating scripts ConfigMap..."
  kubectl create configmap forgejo-scripts \
    --namespace forgejo \
    --from-file=backup.sh="${ROOT_DIR}/scripts/backup.sh" \
    --from-file=restore.sh="${ROOT_DIR}/scripts/restore.sh" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Applying TLS hardening..."
  kubectl apply -f tls-hardening.yml

  echo "Deploying Postgres..."
  kubectl apply -f postgres.yml

  echo "Deploying Forgejo..."
  kubectl apply -f forgejo.yml

  echo "Deploying backup CronJob..."
  kubectl apply -f backup-cronjob.yml
}

# --- Install cert-manager ---

install_cert_manager() {
  if ! kubectl get namespace cert-manager > /dev/null 2>&1; then
    echo "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
    echo "Waiting for cert-manager..."
    kubectl wait --for=condition=Available -n cert-manager deploy/cert-manager-webhook --timeout=120s
  else
    echo "cert-manager already installed."
  fi

  echo "Creating azure-dns-secret..."
  kubectl create secret generic azure-dns-secret \
    --namespace cert-manager \
    --from-literal=client-secret="${AZURE_CLIENT_SECRET}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

# --- Main ---

case "${MODE}" in
  local)
    echo "Deploying Forgejo locally for ${HOSTNAME}..."
    apply_core

    echo ""
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app=postgres -n forgejo --timeout=120s
    kubectl wait --for=condition=Ready pod -l app=forgejo -n forgejo --timeout=120s

    echo ""
    echo "Starting port-forward to localhost:3000..."
    echo "Press Ctrl+C to stop port-forward after setup is complete."
    kubectl port-forward -n forgejo svc/forgejo 3000:3000
    ;;

  expose)
    echo "Exposing Forgejo externally..."
    generate_manifests
    install_cert_manager

    echo "Applying cert-manager issuer..."
    kubectl apply -f cert-manager.yml

    echo "Applying Ingress..."
    kubectl apply -f ingress.yml

    echo ""
    echo "Forgejo is now exposed at https://${HOSTNAME}/"
    echo "TLS certificate will be issued automatically."
    ;;

  update)
    echo "Updating Kubernetes deployment for ${HOSTNAME}..."

    # Backup before changes
    if kubectl get cronjob forgejo-backup -n forgejo > /dev/null 2>&1; then
      echo "Backing up before update..."
      kubectl create job --from=cronjob/forgejo-backup pre-update-backup -n forgejo 2>/dev/null || true
      kubectl wait --for=condition=complete job/pre-update-backup -n forgejo --timeout=120s 2>/dev/null || true
      kubectl delete job pre-update-backup -n forgejo 2>/dev/null || true
    fi

    generate_manifests
    apply_core
    install_cert_manager
    kubectl apply -f cert-manager.yml
    kubectl apply -f ingress.yml

    echo ""
    echo "Update complete."
    ;;

  *)
    echo "Usage: $0 <local|expose|update>"
    exit 1
    ;;
esac

# Health check
echo ""
echo "Pod status:"
kubectl get pods -n forgejo
