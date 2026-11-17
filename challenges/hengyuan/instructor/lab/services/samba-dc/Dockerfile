ARG DEBIAN_IMAGE=debian:bookworm-slim
FROM ${DEBIAN_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      samba samba-dsdb-modules python3-samba smbclient ldap-utils krb5-user \
      ldb-tools procps curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# 构建期 provision: 固定 domain SID + krbtgt hash -> 重置可复现, flag/hash 稳定。
# kerberos encryption types=all 确保 RC4 (Kerberoast/AS-REP 可 crack, hashcat -m 13100/18200)。
RUN samba-tool domain provision \
      --realm=HENGYUAN.LOCAL --domain=HENGYUAN \
      --server-role=dc --dns-backend=SAMBA_INTERNAL \
      --adminpass='Hengyuan@DC2023!' --use-rfc2307 \
      --option="dns forwarder=172.30.3.53" \
      --option="kerberos encryption types=all"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY seed/ /seed/
RUN chmod +x /usr/local/bin/entrypoint.sh /seed/*.sh

EXPOSE 53 88 135 139 389 445 464 636 3268 3269
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]