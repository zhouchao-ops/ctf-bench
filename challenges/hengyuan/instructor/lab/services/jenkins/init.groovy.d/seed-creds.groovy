// 从挂载的私钥文件注入 deploy-ssh-key 凭证 (避免 multiline env)。
// 该私钥同时泄露于 Gitea infra-deploy 历史 (Uber 案例), 认证 fileserver SSH。
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

def j = Jenkins.get()
def store = j.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def keyFile = new File('/usr/share/jenkins/ref/deploy_key/id_rsa')
if (keyFile.exists()) {
    def existing = CredentialsProvider.lookupCredentials(
        com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey.class,
        j, null, Collections.emptyList())
    if (!existing.any { it.id == 'deploy-ssh-key' }) {
        def cred = new BasicSSHUserPrivateKey(
            CredentialsScope.GLOBAL,
            'deploy-ssh-key',
            'deploy',
            new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource(keyFile.text),
            '',
            'fileserver deploy key')
        store.addCredentials(Domain.global(), cred)
    }
}