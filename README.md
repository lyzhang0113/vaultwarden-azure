# Vaultwarden On Azure Container Apps

This repo deploys Vaultwarden on Azure with:

- Azure Container Apps for the application runtime
- Azure Database for PostgreSQL Flexible Server with private network access only
- Azure Files mounted at `/data`
- a public HTTPS ingress endpoint for the app
- environment-variable-based secret input for validation and deployment

The application is public over HTTPS, while the PostgreSQL server stays private inside the deployment VNet.

## Architecture

- `infra/main.bicep` provisions the Container Apps environment, storage account and file share, private PostgreSQL Flexible Server, private DNS zone, and the Vaultwarden container app.
- `infra/scripts/provision-vaultwarden-db-user.sh` creates or rotates the dedicated Vaultwarden database login after the server and database exist.
- `infra/parameters/prod.bicepparam` contains the non-secret production defaults and reads secure values from local environment variables.

## Deployment

Create or select a resource group first:

```bash
az group create --name <resource-group> --location eastasia
```

Export the required secure inputs before validating or deploying:

```bash
export ADMIN_TOKEN='<vaultwarden-admin-token>'
export POSTGRES_ADMIN_PASSWORD='<postgres-admin-password>'
export VAULTWARDEN_DB_PASSWORD='<vaultwarden-db-password>'
```

All three variables are required. `ADMIN_TOKEN` protects the Vaultwarden admin panel. `POSTGRES_ADMIN_PASSWORD` is used to create the PostgreSQL Flexible Server and bootstrap the app login. `VAULTWARDEN_DB_PASSWORD` is used for the dedicated `vaultwarden` database user and the app connection string.

Validate the deployment:

```bash
az deployment group validate \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters infra/parameters/prod.bicepparam
```

Preview the changes if needed:

```bash
az deployment group what-if \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters infra/parameters/prod.bicepparam
```

Deploy:

```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters infra/parameters/prod.bicepparam
```

Get the public app URL after deployment:

```bash
az containerapp show \
  --resource-group <resource-group> \
  --name <container-app-name> \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

The deployed container image tag is pinned through `containerImageTag` in `infra/parameters/prod.bicepparam`.

## Operations

- Backup and restore: `docs/operations/vaultwarden-backup-restore.md`
- Upgrades: `docs/operations/vaultwarden-upgrade.md`

## Notes

- The production parameter file intentionally keeps secrets out of source control.
- `/data` and PostgreSQL are separate state stores; treat them as separate backup and recovery scopes.
- Secure deployment inputs come from environment variables consumed by `infra/parameters/prod.bicepparam`; do not generate or commit JSON parameter files with plaintext secrets.
