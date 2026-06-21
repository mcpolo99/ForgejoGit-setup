# Forgejo Self-Hosted Git Server

Two deployment options: Docker Compose or Kubernetes (K3s).

## Docker Compose

```bash
cd docker/
cp .env.example .env
cp traefik/traefik.yml.example traefik/traefik.yml
cp traefik/dynamic.yml.example traefik/dynamic.yml
# Edit all three files with your values

# Dev (local)
docker compose -f compose.yml -f compose.dev.yml up -d

# Prod
docker compose -f compose.yml -f compose.prod.yml up -d
```

See [docs/](docs/) for detailed setup guides.

## Kubernetes (K3s)

Uses the same `.env` file as Docker. The setup script reads it and creates all K8s secrets, installs cert-manager, and deploys everything:

```bash
# Make sure .env exists (in repo root or docker/)
cd k8s/
# Edit forgejo.yml and ingress.yml — replace git.yourdomain.com with your domain
chmod +x setup.sh
./setup.sh
```

### Create admin user (first time)

```bash
kubectl exec -n forgejo deploy/forgejo -c forgejo -- \
  su-exec git forgejo admin user create \
  --admin --username mawi --password YOUR_PASSWORD --email you@yourdomain.com
```

## Azure ACME (TLS certificates)

1. `az account list -o table`
2. `az group list -o table`
3. `az network dns zone list -o table`
4. `az ad sp create-for-rbac --name traefik-acme --role "DNS Zone Contributor" --scopes /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/dnszones/<domain>`

The output gives you `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, and `AZURE_TENANT_ID`.

## Tea CLI (git client)

```bash
tea login add --name myserver --url https://git.yourdomain.com --token YOUR_TOKEN
tea login default myserver
tea repo create --name my-project --private
```

See [docs/git-client-setup.md](docs/git-client-setup.md).
