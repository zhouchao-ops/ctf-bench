#!/bin/bash
# crown jewels 数据库 schema + 应用角色 hy_app (仅 SELECT customers/finance/employees)。
# crown_jewels 表不授予 hy_app —— 只有 superuser (IT-Backup 泄露凭证) 可读。
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE TABLE IF NOT EXISTS customers (
	  id SERIAL PRIMARY KEY, name TEXT, id_card TEXT, phone TEXT, address TEXT, note TEXT);
	CREATE TABLE IF NOT EXISTS finance (
	  id SERIAL PRIMARY KEY, txn TEXT, amount NUMERIC(12,2), balance NUMERIC(12,2), note TEXT);
	CREATE TABLE IF NOT EXISTS employees (
	  uid SERIAL PRIMARY KEY, username TEXT UNIQUE, dept TEXT, password TEXT);
	CREATE TABLE IF NOT EXISTS crown_jewels (
	  id SERIAL PRIMARY KEY, secret TEXT);
	DO \$\$ BEGIN
	  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='${PG_APP_USER}') THEN
	    CREATE ROLE ${PG_APP_USER} LOGIN PASSWORD '${PG_APP_PW}';
	  END IF;
	END \$\$;
	GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${PG_APP_USER};
	GRANT USAGE ON SCHEMA public TO ${PG_APP_USER};
	GRANT SELECT ON customers, finance, employees TO ${PG_APP_USER};
EOSQL