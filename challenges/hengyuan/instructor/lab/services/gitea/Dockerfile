ARG GITEA_IMAGE=gitea/gitea:1.21
FROM ${GITEA_IMAGE}

USER root
RUN apk add --no-cache git bash curl openssh-keygen
COPY app.ini /etc/gitea/app.ini
COPY entrypoint-seed.sh /usr/local/bin/entrypoint-seed.sh
COPY seed/ /seed/
RUN chmod +x /usr/local/bin/entrypoint-seed.sh /seed/infra-deploy/make_history.sh \
 && mkdir -p /data \
 && chown -R git:git /etc/gitea /seed /data
ENV GITEA_CUSTOM=/etc/gitea
USER git
ENTRYPOINT ["/usr/local/bin/entrypoint-seed.sh"]