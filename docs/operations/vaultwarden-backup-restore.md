# Vaultwarden Backup And Restore

Treat PostgreSQL and `/data` as two separate recovery scopes. A usable recovery point needs both.

## What To Back Up

- PostgreSQL database: Vault items, users, org data, config stored in the database
- Azure Files share mounted at `/data`: attachments, icons, sends, and other file-backed content

## PostgreSQL Backup

Run `pg_dump` against the Flexible Server FQDN from a network path that can reach the private endpoint.

```bash
export PGPASSWORD='<vaultwarden-db-password>'

pg_dump \
  --host <postgres-fqdn> \
  --port 5432 \
  --username vaultwarden \
  --dbname vaultwarden \
  --format custom \
  --file vaultwarden-$(date +%F).dump
```

If you prefer administrative backups, use the server admin account instead. Azure also keeps platform backups for Flexible Server, but keep logical backups when you need app-level restore control.

## Azure Files Backup

Back up the `vw-data` file share separately.

Options:

- Enable Azure Backup for the storage account if you want managed share protection.
- Use share snapshots for short-term rollback.
- Copy the share contents out with `az storage file` or `azcopy` for an external backup.

Example snapshot:

```bash
az storage share snapshot \
  --account-name <storage-account-name> \
  --name vw-data
```

## Restore Order

1. Restore PostgreSQL first.
2. Restore the Azure Files share contents for `/data`.
3. Restart the Container App so the app reconnects with the restored state.

## PostgreSQL Restore

Restore into the target database from a host that can reach the private server.

```bash
export PGPASSWORD='<vaultwarden-db-password>'

pg_restore \
  --host <postgres-fqdn> \
  --port 5432 \
  --username vaultwarden \
  --dbname vaultwarden \
  --clean \
  --if-exists \
  vaultwarden-YYYY-MM-DD.dump
```

If you restore to a new server, make sure the `vaultwarden` login exists and matches `VAULTWARDEN_DB_PASSWORD` before restarting the app.

## Azure Files Restore

- Restore the `vw-data` share from Azure Backup, a share snapshot, or your copied backup set.
- Verify the expected directories and files are back under `/data` before reopening service.

## Final Checks

- Confirm the Container App starts cleanly.
- Sign in and verify recent vault data and attachments.
- Check `/alive` and a few representative attachment downloads.
