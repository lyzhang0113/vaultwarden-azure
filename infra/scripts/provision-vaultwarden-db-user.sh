#!/bin/bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-client >/dev/null
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y postgresql >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y postgresql >/dev/null
  elif command -v tdnf >/dev/null 2>&1; then
    tdnf install -y postgresql >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    yum install -y postgresql >/dev/null
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache postgresql-client >/dev/null
  else
    echo "No supported package manager found to install PostgreSQL client" >&2
    exit 1
  fi
fi

export PGSSLMODE=require

psql --host="$PGHOST" --port=5432 --username="$PGUSER" --dbname=postgres --no-password --set=ON_ERROR_STOP=1 --set=app_db_user="$APP_DB_USER" --set=app_db_password="$APP_DB_PASSWORD" --set=app_db_name="$PGDATABASE" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_db_user', :'app_db_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = :'app_db_user') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'app_db_user', :'app_db_password')
WHERE EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = :'app_db_user') \gexec
SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I', :'app_db_name', :'app_db_user') \gexec
SQL

psql --host="$PGHOST" --port=5432 --username="$PGUSER" --dbname="$PGDATABASE" --no-password --set=ON_ERROR_STOP=1 --set=app_db_user="$APP_DB_USER" <<'SQL'
SELECT format('GRANT USAGE, CREATE ON SCHEMA public TO %I', :'app_db_user') \gexec
SQL
