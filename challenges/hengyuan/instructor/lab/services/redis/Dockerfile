ARG REDIS_IMAGE=redis:7-alpine
FROM ${REDIS_IMAGE}
COPY entrypoint-seed.sh /usr/local/bin/entrypoint-seed.sh
RUN chmod +x /usr/local/bin/entrypoint-seed.sh
EXPOSE 6379
ENTRYPOINT ["/usr/local/bin/entrypoint-seed.sh"]