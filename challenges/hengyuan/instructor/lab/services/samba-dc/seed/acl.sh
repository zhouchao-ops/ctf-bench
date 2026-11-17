#!/bin/bash
# ACL 滥用链 (Samba 兼容):
#   svc_sql  --GenericWrite(GW)-->  svc_backup   (targeted Kerberoasting: 写 SPN)
#   svc_backup --GenericAll(GA)--> itadmin(DA)   (net rpc password 强制改密)
# 注意: Samba 无 PKINIT/shadow-creds, 无 SeBackupPrivilege; 故用上述而非 pywhisker/Backup Operators。
set -e
DN="DC=hengyuan,DC=local"

get_sid() {
  python3 - "$1" <<'PY'
import sys
from samba.samdb import SamDB
from samba.auth import system_session
from samba.param import LoadParm
lp = LoadParm(); lp.load('/etc/samba/smb.conf')
db = SamDB(url='/var/lib/samba/private/sam.ldb', session_info=system_session(), lp=lp)
u = sys.argv[1]
r = db.search(base='DC=hengyuan,DC=local', expression='(sAMAccountName=%s)' % u, attrs=['objectSid'])
sid = db.schema_format_value('objectSid', r[0]['objectSid'][0])
print(sid.decode() if isinstance(sid, bytes) else sid)
PY
}

SQL_SID="$(get_sid "${AD_SVC_SQL_USER}")"
BAK_SID="$(get_sid "${AD_SVC_BACKUP_USER}")"

samba-tool dsacl set \
  --objectdn="CN=${AD_SVC_BACKUP_USER},OU=ServiceAccounts,${DN}" \
  --sddl="(A;;GW;;;${SQL_SID})"
samba-tool dsacl set \
  --objectdn="CN=${AD_ITADMIN_USER},OU=IT,${DN}" \
  --sddl="(A;;GA;;;${BAK_SID})"