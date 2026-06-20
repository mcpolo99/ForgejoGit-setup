
# run it

## DEV (local LAN)

<!-- docker compose --profile dev up -d -->
<!-- docker compose -f compose.yml -f compose.dev.yml up -d -->
docker compose -f compose.yml -f compose.dev.yml up -d --force-recreate

## Prod

<!-- docker compose --profile prod up -d -->
docker compose -f compose.yml -f compose.prod.yml up -d

## Azure ACME

1. get subscriptions : `az account list -o table`
2. Get resource group : `az group list -o table`
3. Find dns zone : `az network dns zone list -o table`
4. final command to get address: `az network dns zone show --name <domain.com>  --resource-group <resource_group> --query id -o tsv`
5. create the pricipal `az ad sp create-for-rbac --name traefik-acme --role "DNS Zone Contributor" --scopes /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/dnszones/<domain>`


    ```json
        {
        "appId": AZURE_CLIENT_ID ,
        "displayName": "traefik-acme",
        "password": AZURE_CLIENT_SECRET,
        "tenant": AZURE_TENANT_ID
        }
    ```

6. update .env

## install lazy docker

curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

~/.local/bin/
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
