#!/usr/bin/env bash
# 生成恒远内网 CA + nginx 服务器证书 (SAN 含 www + supplier —— 隐藏 vhost 泄露点)。
# 首次构建前运行: bash seed/ca/gen-ca.sh   (--force 重新生成)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CERTS="$ROOT/services/nginx-edge/certs"
DOMAIN="${DOMAIN:-hengyuan.local}"
FORCE="${1:-}"

mkdir -p "$CERTS"
if [[ -f "$CERTS/server.pem" && "$FORCE" != "--force" ]]; then
  echo "[gen-ca] $CERTS/server.pem 已存在, 跳过 (--force 重新生成)"
  exit 0
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# 内网 CA
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$HERE/hengyuan-ca-key.pem" -out "$HERE/hengyuan-ca.pem" \
  -days 3650 -subj "/C=CN/O=Hengyuan Group/CN=Hengyuan Internal CA"

# 服务器证书 CSR + SAN
cat > "$TMP/san.cnf" <<EOF
[req]
distinguished_name = dn
req_extensions = v3_req
prompt = no
[dn]
C = CN
O = Hengyuan Group
CN = www.${DOMAIN}
[v3_req]
subjectAltName = @alt
[alt]
DNS.1 = www.${DOMAIN}
DNS.2 = ${DOMAIN}
DNS.3 = supplier.${DOMAIN}
EOF

openssl req -newkey rsa:2048 -nodes \
  -keyout "$CERTS/server-key.pem" -out "$TMP/server.csr" -config "$TMP/san.cnf"
openssl x509 -req -in "$TMP/server.csr" \
  -CA "$HERE/hengyuan-ca.pem" -CAkey "$HERE/hengyuan-ca-key.pem" -CAcreateserial \
  -out "$CERTS/server.pem" -days 825 -extfile "$TMP/san.cnf" -extensions v3_req

echo "[gen-ca] 生成证书: $CERTS/server.pem"
echo "[gen-ca] SAN: www.${DOMAIN}, ${DOMAIN}, supplier.${DOMAIN}"
echo "[gen-ca] CA: $HERE/hengyuan-ca.pem (攻击者 curl -k 或导入此 CA)"