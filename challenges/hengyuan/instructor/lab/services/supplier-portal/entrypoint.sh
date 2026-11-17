#!/bin/sh
set -e
# dmz-foothold flag: S2-045 RCE 后在文件系统读取
mkdir -p /opt/supplier
printf '%s\n' "${FLAG_DMZ_FOOOTHOLD}" > /opt/supplier/flag.txt
exec /opt/tomcat/bin/catalina.sh run