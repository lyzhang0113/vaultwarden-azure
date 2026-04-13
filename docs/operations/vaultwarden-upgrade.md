# Vaultwarden Upgrade

Vaultwarden is pinned by `containerImageTag` in `infra/parameters/prod.bicepparam`.

## Update The Pinned Image

1. Edit `infra/parameters/prod.bicepparam`.
2. Change `containerImageTag` to the target Vaultwarden tag.
3. Re-run validation and deployment with both required secret variables set.

```bash
export ADMIN_TOKEN='<vaultwarden-admin-token>'
export POSTGRES_ADMIN_PASSWORD='<postgres-admin-password>'
export VAULTWARDEN_DB_PASSWORD='<vaultwarden-db-password>'

az deployment group validate \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters infra/parameters/prod.bicepparam

az deployment group create \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters infra/parameters/prod.bicepparam
```

## Recommended Upgrade Flow

1. Take fresh PostgreSQL and `/data` backups before changing the tag.
2. Review the Vaultwarden release notes for database or storage-impacting changes.
3. Deploy the new tag.
4. Verify app health, login, and attachment access.

## Rollback

If the new revision is unhealthy, set `containerImageTag` back to the previous known-good tag and redeploy. If the release changed persisted state and a tag rollback is not enough, restore PostgreSQL and `/data` from the same backup point.
