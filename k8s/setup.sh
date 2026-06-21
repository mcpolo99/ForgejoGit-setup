#!/bin/sh
set -e

# Reads from ../.env (or ../docker/.env) and creates all K8s secrets + cert-manager issuer.
# Usage: cd k8s && ./setup.sh

ENV_FILE=""
if [ -f "../.env" ]; then
  ENV_FILE="../.env"
elif [ -f "../docker/.env" ]; then
  ENV_FILE="../docker/.env"
else
  echo "ERROR: No .env file found. Copy .env.example and fill in your values."
  exit 1
fi

echo "Loading config from ${ENV_FILE}..."
while IFS='=' read -r key value; do
  case "$key" in
    \#*|""|UID|GID) continue ;;
    *) export "$key=$value" ;;
  esac
done < "${ENV_FILE}"

# 1. Create namespace
echo "Creating namespace..."
kubectl apply -f namespace.yml

# 2. Create Forgejo secrets
echo "Creating forgejo-secrets..."
kubectl create secret generic forgejo-secrets \
  --namespace forgejo \
  --from-literal=POSTGRES_DB="${POSTGRES_DB}" \
  --from-literal=POSTGRES_USER="${POSTGRES_USER}" \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Install cert-manager (if not already installed)
if ! kubectl get namespace cert-manager > /dev/null 2>&1; then
  echo "Installing cert-manager..."
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
  echo "Waiting for cert-manager..."
  kubectl wait --for=condition=Available -n cert-manager deploy/cert-manager-webhook --timeout=120s
else
  echo "cert-manager already installed."
fi

# 4. Create Azure DNS secret for cert-manager
echo "Creating azure-dns-secret..."
kubectl create secret generic azure-dns-secret \
  --namespace cert-manager \
  --from-literal=client-secret="${AZURE_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Apply ClusterIssuer with values from .env
echo "Creating ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${ACME_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod-account
    solvers:
      - dns01:
          azureDNS:
            clientID: ${AZURE_CLIENT_ID}
            clientSecretSecretRef:
              name: azure-dns-secret
              key: client-secret
            subscriptionID: ${AZURE_SUBSCRIPTION_ID}
            tenantID: ${AZURE_TENANT_ID}
            resourceGroupName: ${AZURE_RESOURCE_GROUP}
            hostedZoneName: ${AZURE_ZONE_NAME}
EOF

# 6. Create scripts ConfigMap from shared scripts
echo "Creating scripts ConfigMap..."
kubectl create configmap forgejo-scripts \
  --namespace forgejo \
  --from-file=backup.sh=../scripts/backup.sh \
  --from-file=restore.sh=../scripts/restore.sh \
  --dry-run=client -o yaml | kubectl apply -f -

# 7. Apply TLS hardening
echo "Applying TLS hardening..."
kubectl apply -f tls-hardening.yml

# 8. Deploy everything
echo "Deploying Postgres..."
kubectl apply -f postgres.yml

echo "Deploying Forgejo..."
kubectl apply -f forgejo.yml

echo "Deploying Ingress..."
kubectl apply -f ingress.yml

echo "Deploying backup CronJob..."
kubectl apply -f backup-cronjob.yml

echo ""
echo "Done! Waiting for pods..."
kubectl get pods -n forgejo -w
