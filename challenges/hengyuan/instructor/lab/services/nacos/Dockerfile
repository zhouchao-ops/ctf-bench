ARG NACOS_IMAGE=nacos/nacos-server:v2.5.1
FROM ${NACOS_IMAGE}

USER root
COPY entrypoint-seed.sh /usr/local/bin/entrypoint-seed.sh
RUN chmod +x /usr/local/bin/entrypoint-seed.sh
WORKDIR /home/nacos

# 包装官方入口: 启动 nacos -> 等待就绪 -> 导入配置 loot -> 前台守护
ENTRYPOINT ["/usr/local/bin/entrypoint-seed.sh"]