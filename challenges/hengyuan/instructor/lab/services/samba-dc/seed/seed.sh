#!/bin/bash
# 幂等在线种子: OU/用户/组/AS-REP UAC/Kerberoast SPN/属性 flag/ACL。
# 用户密码固定 (来自 compose env) -> 重置后 hash 稳定。
set -e
DN="DC=hengyuan,DC=local"
BIND="CN=Administrator,CN=Users,${DN}"
LDAP="ldap://127.0.0.1"
PW="${DC_ADMIN_PW}"

ldmod() { ldapmodify -x -H "$LDAP" -D "$BIND" -w "$PW" >/dev/null 2>&1 || true; }

# OU
for ou in Employees ServiceAccounts IT; do
  samba-tool ou create "OU=${ou},${DN}" >/dev/null 2>&1 || true
done

# 用户 (幂等)
samba-tool user create "${AD_CONTRACTOR_USER}" "${AD_CONTRACTOR_PW}" --userou="OU=Employees" --given-name=Li --surname=Contractor >/dev/null 2>&1 || true
samba-tool user create "${AD_SVC_SQL_USER}" "${AD_SVC_SQL_PW}" --userou="OU=ServiceAccounts" --given-name=SQL --surname=Service >/dev/null 2>&1 || true
samba-tool user create "${AD_SVC_BACKUP_USER}" "${AD_SVC_BACKUP_PW}" --userou="OU=ServiceAccounts" --given-name=Backup --surname=Service >/dev/null 2>&1 || true
samba-tool user create "${AD_ITADMIN_USER}" "${AD_ITADMIN_PW}" --userou="OU=IT" --given-name=IT --surname=Admin >/dev/null 2>&1 || true
samba-tool group addmembers "Domain Admins" "${AD_ITADMIN_USER}" >/dev/null 2>&1 || true

# AS-REP roastable: DONT_REQ_PREAUTH (UAC 512|4194304 = 4194816)
ldmod <<LDIF
dn: CN=${AD_CONTRACTOR_USER},OU=Employees,${DN}
changetype: modify
replace: userAccountControl
userAccountControl: 4194816
LDIF

# Kerberoastable SPN (RC4 TGS, hashcat -m 13100)
samba-tool spn add "MSSQLSvc/sql01.hengyuan.local:1433" "${AD_SVC_SQL_USER}" >/dev/null 2>&1 || true

# flag 藏于属性 (crack/auth 后 LDAP 可读)
ldmod <<LDIF
dn: CN=${AD_CONTRACTOR_USER},OU=Employees,${DN}
changetype: modify
replace: description
description: ${FLAG_ASREP}
LDIF
ldmod <<LDIF
dn: CN=${AD_SVC_SQL_USER},OU=ServiceAccounts,${DN}
changetype: modify
replace: info
info: ${FLAG_KERBEROAST}
LDIF
ldmod <<LDIF
dn: CN=${AD_SVC_BACKUP_USER},OU=ServiceAccounts,${DN}
changetype: modify
replace: info
info: ${FLAG_ACL}
LDIF

# ACL 滥用链 (GenericWrite -> targeted Kerberoast; GenericAll -> DA 改密)
bash /seed/acl.sh