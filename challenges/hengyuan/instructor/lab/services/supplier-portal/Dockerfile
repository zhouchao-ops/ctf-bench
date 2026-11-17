# ============================================================================
# 遗留供应商门户 — Struts2 2.3.31 (S2-045 / CVE-2017-5638, Equifax 2017)
# 100% arm64 安全: Maven/Tomcat 均为纯 Java, 运行于 temurin8 (arm64)。
# 不使用 arch 专属 tomcat 镜像, 避免 qemu 模拟。
# ============================================================================
ARG TEMURIN_IMAGE=eclipse-temurin:8-jdk

# ---- Stage 1: 构建 WAR ----
FROM ${TEMURIN_IMAGE} AS build
ARG MAVEN_VER=3.8.8
RUN apt-get update && apt-get install -y --no-install-recommends curl tar ca-certificates git \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VER}/binaries/apache-maven-${MAVEN_VER}-bin.tar.gz \
    | tar xz -C /opt
ENV PATH=/opt/apache-maven-${MAVEN_VER}/bin:${PATH}
WORKDIR /src
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
# 诱饵: 构建期生成可 dump 的假 .git (D3, 凭证仅 honeypot 生效) + 假 server-status banner (D4)
COPY decoy/ ./decoy/
RUN sh ./decoy/make-decoy-git.sh \
 && mkdir -p ./src/main/webapp/.git \
 && cp -r ./decoy/.git/. ./src/main/webapp/.git/ \
 && cp ./decoy/server-status.html ./src/main/webapp/server-status.html
RUN mvn -q -B clean package -DskipTests

# ---- Stage 2: 运行于 Tomcat 8.5 二进制 (纯 Java) ----
FROM ${TEMURIN_IMAGE}
ARG TOMCAT_VER=8.5.99
RUN apt-get update && apt-get install -y --no-install-recommends curl tar ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-8/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz \
    | tar xz -C /opt \
 && mv /opt/apache-tomcat-${TOMCAT_VER} /opt/tomcat \
 && rm -rf /opt/tomcat/webapps/*
# 预解包 WAR 为 exploded ROOT (maven-war-plugin 默认排除 .git, 故诱饵静态文件在此烘焙)
COPY --from=build /src/target/supplier.war /tmp/supplier.war
RUN mkdir -p /opt/tomcat/webapps/ROOT \
 && cd /opt/tomcat/webapps/ROOT \
 && jar xf /tmp/supplier.war \
 && rm -f /tmp/supplier.war
# D3: 可 dump 的假 .git (凭证仅 honeypot 生效); D4: /server-status 假 banner (无扩展名路径)
# 注: COPY 整个 decoy 目录再 cp, 避免 BuildKit 将 .git 源路径误判为 git ref
COPY --from=build /src/decoy /opt/decoy
RUN cp -r /opt/decoy/.git /opt/tomcat/webapps/ROOT/.git \
 && cp /opt/decoy/server-status.html /opt/tomcat/webapps/ROOT/server-status.html \
 && cp /opt/decoy/server-status.html /opt/tomcat/webapps/ROOT/server-status \
 && rm -rf /opt/decoy
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENV JAVA_OPTS="-Xmx256m -Xms128m"
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]