// 种子 freestyle job。job 的 config.xml (含 shell 脚本) 可经 CVE-2024-23897 文件读取,
// 脚本内容泄露内网主机名/路径, 引导 pivot。backup-dc 为 D6 诱饵 (沙箱, 无真实凭证)。
import jenkins.model.*
import hudson.model.*
import hudson.tasks.*

def j = Jenkins.get()

def mkJob = { String name, String script ->
    if (j.getItem(name) == null) {
        def job = new FreeStyleProject(j, name)
        job.buildersList.add(new Shell(script))
        job.save()
    }
}

mkJob('deploy-supplier-portal', '''#!/bin/bash
# 部署遗留供应商门户
echo "deploying supplier.war -> supplier (172.30.2.20:8080)"
echo "corp jump: jenkins 172.30.3.40 -> devops gitea 172.30.4.20:3000"
echo "config center: nacos 172.30.3.30:8848"
''')

mkJob('vendor-onboarding', '''#!/bin/bash
# OA 报销审批通过后自动开通 vendor 访问 (业务集成)
echo "provision vendor token via OA webhook"
echo "jenkins vendor user: vendor (Overall/Read)"
''')

mkJob('backup-dc', '''#!/bin/bash
# 域控备份 (看似敏感)
echo "backup dc01 (172.30.3.10) ..."
echo "flag{hengyuan_decoy_backup_dc_000000}"
echo "[sandbox] no real credentials available in this job"
''')