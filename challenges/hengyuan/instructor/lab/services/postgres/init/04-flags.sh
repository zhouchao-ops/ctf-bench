#!/bin/bash
# crown-jewel flag: superuser-only 表 (hy_app 无 SELECT 权限)。
# 凭证经 fileserver IT-Backup$ 的 postgres-superuser.yaml 泄露 (Path C 终局)。
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	INSERT INTO crown_jewels (secret) VALUES
	 ('${FLAG_CROWN_JEWEL}'),
	 ('恒远集团核心客户库主密钥 (合成)');
	REVOKE ALL ON crown_jewels FROM PUBLIC;
EOSQL