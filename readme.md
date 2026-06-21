# Forgejo Self-Hosted Git Server

Self-hosted git server with automated TLS, backups, and two deployment options: Docker Compose or Kubernetes (K3s).

## Quick Start

### Linux

```bash
git clone https://github.com/mcpolo99/ForgejoGit-setup.git
cd ForgejoGit-setup
chmod +x run.sh
./run.sh
```

### Windows

```cmd
git clone https://github.com/mcpolo99/ForgejoGit-setup.git
cd ForgejoGit-setup
run.cmd
```

`run.cmd` auto-installs Git, Docker Desktop, and Tea CLI if missing, then launches `run.sh` via Git Bash.

The script handles everything:
- Installs prerequisites (Docker/K3s/Tea CLI)
- Configures secrets interactively or via file
- Deploys locally for initial setup (Forgejo install wizard)
- Exposes externally with TLS after setup is complete
- On subsequent runs: backs up and updates

Linux supports Docker and Kubernetes (K3s). Windows supports Docker only.

## Manual Setup

If you prefer to set things up manually, see:
- [docs/git-client-setup.md](docs/git-client-setup.md) — SSH keys, Tea CLI, pushing repos
- [docs/backup-and-restore.md](docs/backup-and-restore.md) — backup config, restore, host migration

### Docker Compose

```bash
cd docker/
cp .env.example .env                          # edit with your values
cp traefik/traefik.yml.example traefik/traefik.yml
cp traefik/dynamic.yml.example traefik/dynamic.yml
docker compose -f compose.yml -f compose.prod.yml up -d
```

### Kubernetes (K3s)

```bash
cd k8s/
cp secrets.yml.example secrets.yml            # edit with your values
../scripts/setup-k8s.sh local                 # deploy locally for setup wizard
../scripts/setup-k8s.sh expose                # expose externally with TLS
```

## Azure DNS (TLS Certificates)

```bash
az ad sp create-for-rbac --name traefik-acme \
  --role "DNS Zone Contributor" \
  --scopes /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/dnszones/<domain>
```

The output provides `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, and `AZURE_TENANT_ID`.
