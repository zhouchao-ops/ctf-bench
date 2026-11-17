ARG DEBIAN_IMAGE=debian:bookworm-slim
FROM ${DEBIAN_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      samba smbclient winbind libnss-winbind openssh-server krb5-user \
      ldap-utils python3 procps curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY smb.conf /etc/samba/smb.conf
COPY krb5.conf /etc/krb5.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY shares/ /srv/shares/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 139 445
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]