ARG NGINX_IMAGE=nginx:stable-alpine
FROM ${NGINX_IMAGE}

# 证书由 seed/ca/gen-ca.sh 在首次构建前生成 (SAN 含 www + supplier, 隐藏 vhost 泄露点)
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/
COPY html/ /var/www/
COPY certs/ /etc/nginx/certs/

EXPOSE 80 443