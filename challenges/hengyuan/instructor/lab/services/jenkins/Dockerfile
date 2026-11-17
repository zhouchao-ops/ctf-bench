# 精确固定 2.426.2 (CVE-2024-23897 在 2.426.3 修复)。arm64 已确认。
ARG JENKINS_IMAGE=jenkins/jenkins:2.426.2-lts-jdk17
FROM ${JENKINS_IMAGE}

USER root
# 插件版本须与 core 2.426.2 兼容 (构建期 jenkins-plugin-cli 会校验)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# JCasC 放在非 volume 路径, 避免被 jenkins_home 命名卷遮蔽
COPY casc.yaml /usr/share/jenkins/casc.yaml
COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

USER jenkins
ENV JAVA_OPTS="-Xmx512m -Xms256m -Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc.yaml
EXPOSE 8080 50000