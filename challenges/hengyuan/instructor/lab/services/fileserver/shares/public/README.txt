恒远集团内网文件服务器 (fileserver)
==================================
内网地址: 172.30.3.50 (corp) / 172.30.5.50 (data)
服务: SMB (445) + SSH (22)

共享:
  finance-docs  财务部报销凭证 (Domain Users)
  public        公共提示 (Domain Users)
  IT-Backup$    IT 备份 (仅 Domain Admins, 隐藏)
  DA-Only$      域管专用 (仅 Domain Admins, 隐藏)

运维备注: deploy 账户用于自动化部署, SSH 公钥已安装。
私钥由 DevOps 仓库管理 (勿提交到代码库!)。