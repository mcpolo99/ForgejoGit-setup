#!/bin/sh
# Azure DNS provider — prompts for credentials and returns values.
# Sourced by configure-secrets.sh

dns_provider_name() {
  echo "Azure DNS"
}

dns_prompt_credentials() {
  echo ""
  echo "=== Azure DNS Configuration ==="
  echo "Create a service principal with DNS Zone Contributor role:"
  echo "  az ad sp create-for-rbac --name traefik-acme \\"
  echo "    --role 'DNS Zone Contributor' \\"
  echo "    --scopes /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/dnszones/<domain>"
  echo ""

  printf "Azure Client ID (appId): " && read -r AZURE_CLIENT_ID
  printf "Azure Client Secret (password): " && read -r AZURE_CLIENT_SECRET
  printf "Azure Tenant ID: " && read -r AZURE_TENANT_ID
  printf "Azure Subscription ID: " && read -r AZURE_SUBSCRIPTION_ID
  printf "Azure Resource Group: " && read -r AZURE_RESOURCE_GROUP
  printf "Azure DNS Zone Name (e.g. yourdomain.com): " && read -r AZURE_ZONE_NAME

  export AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID
  export AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP AZURE_ZONE_NAME
}

dns_cert_manager_solver() {
  cat <<EOF
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
}

dns_k8s_secret() {
  echo "  AZURE_CLIENT_ID: ${AZURE_CLIENT_ID}"
  echo "  AZURE_CLIENT_SECRET: ${AZURE_CLIENT_SECRET}"
  echo "  AZURE_TENANT_ID: ${AZURE_TENANT_ID}"
  echo "  AZURE_SUBSCRIPTION_ID: ${AZURE_SUBSCRIPTION_ID}"
  echo "  AZURE_RESOURCE_GROUP: ${AZURE_RESOURCE_GROUP}"
  echo "  AZURE_ZONE_NAME: ${AZURE_ZONE_NAME}"
}

dns_docker_env() {
  echo "AZURE_CLIENT_ID=${AZURE_CLIENT_ID}"
  echo "AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}"
  echo "AZURE_TENANT_ID=${AZURE_TENANT_ID}"
  echo "AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}"
  echo "AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}"
  echo "AZURE_ZONE_NAME=${AZURE_ZONE_NAME}"
}
