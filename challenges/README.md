# CTF 培训题包（6 题：5 题本地可复现 + 1 题 Docker 内网靶场）

这是一个面向 CTF 培训的偏难题包，覆盖 **Web / Crypto / Reverse / Pwn / Forensics** 五个方向。
所有题目、服务、二进制、抓包和 flag 均为本地合成数据，不包含真实目标，不依赖公网，
不修改系统配置。题包只提供题目与配套环境，不包含计分平台或网站。

其中前 5 题（web/crypto/reverse/pwn/forensics）纯本地、仅用标准库即可复现；第 6 题
`hengyuan` 是一套多容器企业内网渗透靶场（service 型），需要宿主机 Docker + Docker
Compose，由 `verify_all.py` 之外的独立脚本启动与验证。

## 1. 题目总览

| # | 题名 | 方向 | 核心知识点 | 分值 | 难度 | 预计时间 | 启动 / 停止 |
|---|------|------|------------|------|------|----------|-------------|
| 1 | 打折商店的负数订单 | Web | 前端泄露、Base64、业务逻辑、负数校验 | 100 | 中等偏难 | 25–35 分钟 | `cd web && ./start.sh 8080` / `./stop.sh` |
| 2 | 一次迁移，两次复用 | Crypto | 口令派生流密码、Nonce 复用、已知明文 | 120 | 中等偏难 | 25–40 分钟 | 无服务；`cd crypto && ./generate.sh` |
| 3 | 去符号的链式许可证 | Reverse | 去符号 ELF、`.rodata` 数据块、字节置换、相邻字节链 | 160 | 难 | 40–60 分钟 | 无服务；`cd reverse && ./build.sh` |
| 4 | 双门本地覆盖：cookie 与 admin | Pwn | 随机 challenge、cookie 计算、栈布局、双字段覆盖 | 140 | 中等偏难 | 35–50 分钟 | 无服务；`cd pwn && ./build.sh` |
| 5 | DNS 隧道里的碎片 | Forensics | PCAP、DNS、TXT 记录、数据重组 | 120 | 难 | 30–45 分钟 | 无服务；`cd forensics && ./generate.sh` |
| 6 | 恒远集团内网渗透 | Web | 多容器内网、S2-045 RCE、业务逻辑链、git 历史密钥、pivot | 1000 | 难 | 90–180 分钟 | 需 Docker；`cd hengyuan && ./start.sh` / `./stop.sh` |

**总分：1640 分（前 5 题 640 + hengyuan 1000）。**

每题都包含：

- `challenge.md`：学员题面；
- `public/`：发给学员的附件（Web 为前端文件，其他题为二进制/抓包/密文）；
- `instructor/`：讲师材料，含 `flag.txt`、生成/构建源码、`walkthrough.md`；
- `solve.py`：可运行的参考解题脚本；
- 运行或生成脚本：Web 的 `start.sh` / `stop.sh`，其余题的 `build.sh` 或 `generate.sh`。

## 2. 测试环境

本机实测环境：

```text
OS:      Ubuntu 22.04.5 LTS x86_64
Kernel:  5.15.0-143-generic
Python:  3.13.5（Anaconda 打包版，全部使用标准库）
GCC:     11.4.0 (Ubuntu 11.4.0-1ubuntu1~22.04)
Binutils: nm / objdump / readelf 可用
```

前 5 题不需要安装第三方 Python 包，不需要 Docker，不需要 root，不需要下载大文件。
`verify_all.py` 只使用 Python 标准库，并调用系统 `gcc`、`nm`、`objdump`、`readelf`。
如果在其他 Ubuntu 22.04 x86_64 设备上运行，只要具备 `python3`、`gcc`、`binutils` 即可。

**例外**：`hengyuan` 需要 Docker + Docker Compose，首次启动会构建镜像（耗时较长、占用
较多内存），不在 `verify_all.py` 的 5 题范围内，单独用 `hengyuan/start.sh` 起靶场验证。

## 3. 目录结构

```text
ctf-training/
├── README.md                 # 本文件
├── verify_all.py             # 一键验证全部 5 题
├── verification-report.txt   # 最近一次统一验证的完整输出
├── web/
│   ├── challenge.md          # 学员题面
│   ├── public/               # 学员材料：index.html, app.js
│   ├── instructor/           # 讲师材料：server.py, flag.txt, walkthrough.md
│   ├── solve.py              # 参考解题
│   ├── start.sh              # 启动 127.0.0.1 服务
│   └── stop.sh               # 停止服务
├── crypto/
│   ├── challenge.md
│   ├── public/               # ciphertexts.json, leaked_memo.txt, encrypt.py
│   ├── instructor/           # make_challenge.py, flag.txt, walkthrough.md
│   ├── solve.py
│   └── generate.sh
├── reverse/
│   ├── challenge.md
│   ├── public/               # checker 二进制（stripped）
│   ├── instructor/           # src/, build.py, flag.txt, walkthrough.md
│   ├── solve.py
│   └── build.sh
├── pwn/
│   ├── challenge.md
│   ├── public/               # pwnme 二进制（随机 cookie 门 + 双字段覆盖）
│   ├── instructor/           # src/, build.py, flag.txt, walkthrough.md
│   ├── solve.py
│   └── build.sh
├── forensics/
│   ├── challenge.md
│   ├── public/               # capture.pcap
│   ├── instructor/           # make_pcap.py, flag.txt, walkthrough.md
│   ├── solve.py
│   └── generate.sh
└── hengyuan/                 # 多容器企业内网靶场（service，需 Docker Compose）
    ├── challenge.md          # 黑盒题面（仅场景/入口/目标）
    ├── public/               # 占位说明（无 flag）
    ├── instructor/           # flag.txt(4)、server.py、walkthrough.md、lab/(compose+services+seed)
    ├── solve.py              # 参考解（仅恢复 DMZ 立足点 flag）
    └── start.sh / stop.sh    # docker compose 起停
```

## 4. 一键验证

在题包根目录运行：

```bash
python3 verify_all.py
```

它会：

1. 为 Web 题启动一个只监听 `127.0.0.1` 的随机端口服务；
2. 依次运行 5 道题的 `solve.py`；
3. 从每份 `instructor/flag.txt` 读取期望 flag，与解题输出比对；
4. 检查 `public/` 中是否出现明文 flag；
5. 关闭 Web 服务，输出 PASS/FAIL 表和耗时。

`hengyuan` 为 Docker service 题，不由 `verify_all.py` 覆盖；单独用 `hengyuan/start.sh`
起靶场后验证（见下文各题运行方法）。

本机最近一次实际验证结果：

```text
==========================================================================
CTF Training Package -- one-click verification
workspace: /home/chao/dsh-workspace/ctf-training
python:    3.13.5
==========================================================================

CHALLENGE    RESULT    TIME  DETAIL
--------------------------------------------------------------------------
web          PASS      0.2s  solver recovered the expected flag
crypto       PASS      0.0s  solver recovered the expected flag
reverse      PASS      0.0s  solver recovered the expected flag
pwn          PASS      0.0s  solver recovered the expected flag
forensics    PASS      0.0s  solver recovered the expected flag

==========================================================================
summary: 5/5 passed, 0 failed
==========================================================================
```

完整验证输出已同步保存到 `verification-report.txt`。

单题失败时，脚本会打印该题 `solve.py` 的 stdout/stderr，便于讲师定位环境问题。

## 5. 各题运行方法

### Web — 打折商店的负数订单

```bash
cd web
./start.sh 8080
# 浏览器访问 http://127.0.0.1:8080
python3 solve.py --url http://127.0.0.1:8080
./stop.sh
```

- 默认绑定 `127.0.0.1`，不会暴露到局域网；
- `./start.sh 0` 可使用随机端口，实际端口写入 `web/.server.port`；
- 服务端 flag 从 `web/instructor/flag.txt` 读取，**不在 `public/` 中**。

### Crypto — 一次迁移，两次复用

```bash
cd crypto
./generate.sh          # 可选：重新生成密文和泄露备忘
python3 solve.py
```

无需启动服务，不需要密码。

### Reverse — 去符号的链式许可证

```bash
cd reverse
./build.sh             # 可选：从 instructor/src 重新编译并 strip
python3 solve.py
# 或手动：printf 'R3v_P3rm_Ch41n_2025!\n' | ./public/checker
```

`solve.py` 只读取 `public/checker`：先用 `readelf` 定位 `.rodata`，解析带标记的
许可证数据块，再逆字节置换和相邻字节链恢复 key，最后让原程序解码 flag。
它不读取 `instructor/secret.h` 或 `instructor/flag.txt`。

### Pwn — 双门本地覆盖：cookie 与 admin

```bash
cd pwn
./build.sh             # 可选：重新编译
python3 solve.py
# 或手动观察两道门：
# objdump -d -M intel --disassemble=main public/pwnme
# objdump -d -M intel --disassemble=mix_challenge public/pwnme
```

程序每次打印随机 `challenge`，第一道门要求输入正确 cookie；第二道门要求一个
同时设置 `admin = 0x1337` 和 `auth = cookie` 的溢出载荷。整个过程只覆盖本地进程的
栈变量并调用题内 `win()` 打印 flag，不生成 shell、不发起网络连接。

### Forensics — DNS 隧道里的碎片

```bash
cd forensics
./generate.sh          # 可选：重新合成 PCAP
python3 solve.py
```

有 tshark 时也可以：

```bash
tshark -r public/capture.pcap -Y dns -T fields -e dns.qry.name
tshark -r public/capture.pcap -Y 'dns.txt' -T fields -e dns.qry.name -e dns.txt
```

### Web — 恒远集团内网渗透（hengyuan，需 Docker）

```bash
cd hengyuan
./start.sh             # 生成证书/密钥 -> docker compose -f instructor/lab/docker-compose.slim.yml up --build --wait
# 入口为 HTTPS 自签证书；默认 vhost 反代集团门户，供应商门户需 Host: supplier.hengyuan.local
python3 solve.py --url https://127.0.0.1:<port>   # 参考解仅恢复 DMZ 立足点 flag
./stop.sh              # docker compose down -v 回收
```

- 精简版 9 容器（nginx/portal/soc/supplier/oa/redis/coredns/gitea/postgres），nginx 仅绑
  `127.0.0.1`，经 SSH 隧道访问；内网设施需 pivot。
- 4 个 flag 按比例计分（共 1000）：S2-045 RCE 立足点、客户 PII、OA 审批竞态、Gitea git 历史密钥。
- 首次 `start` 需构建镜像，耗时较长；`instructor/`（含 lab、flag、walkthrough）不下发给学员。

## 6. 学员分发边界

**通用规则：学员只应收到每题的 `challenge.md` 和 `public/` 目录。**

| 题目 | 发给学员 | 不发给学员（讲师保留） |
|------|----------|------------------------|
| Web | `web/challenge.md`、`web/public/` | `web/instructor/`（含 server.py、flag.txt、walkthrough.md）、`web/solve.py`、`start.sh`、`stop.sh` |
| Crypto | `crypto/challenge.md`、`crypto/public/` | `crypto/instructor/`、`crypto/solve.py`、`generate.sh` |
| Reverse | `reverse/challenge.md`、`reverse/public/checker` | `reverse/instructor/`（src、build.py、flag.txt、walkthrough.md）、`reverse/solve.py`、`build.sh` |
| Pwn | `pwn/challenge.md`、`pwn/public/pwnme` | `pwn/instructor/`、`pwn/solve.py`、`build.sh` |
| Forensics | `forensics/challenge.md`、`forensics/public/capture.pcap` | `forensics/instructor/`、`forensics/solve.py`、`generate.sh` |
| Hengyuan | `hengyuan/challenge.md`、`hengyuan/public/` | `hengyuan/instructor/`（lab、flag.txt、server.py、walkthrough.md）、`hengyuan/solve.py`、`start.sh`、`stop.sh` |

边界说明：

- Web 服务端的 flag 只在 `web/instructor/flag.txt`，运行中的服务不会把该文件放进静态目录。
- Reverse 的 `public/checker` 已 stripped，key 和 flag 都不以明文出现；Pwn 的 flag 以 XOR 编码形式嵌入二进制。`public/` 中不存在明文 flag；这是本地逆向/Pwn 题的预期分析对象。
- Crypto/Forensics 的 flag 以密文或十六进制碎片形式存在，`public/` 中不存在明文 flag。
- `verify_all.py` 会额外扫描 `public/`，若发现明文 flag 会判 FAIL。
- 根目录 `README.md`、`verify_all.py`、`verification-report.txt`、各题 `walkthrough.md` 和 `solve.py` 都属于讲师材料，不要发给学员。

## 7. 安全与范围

- 全部服务只绑定 `127.0.0.1`；不存在远程目标或真实域名。
- 所有数据（商品、密文、二进制、PCAP、DNS 域名/IP、flag）均为本地合成。
- 前 5 题不执行系统配置变更，不安装软件包，不下载大文件，不生成 shell。`hengyuan` 例外：
  其 Docker 镜像首次构建会从镜像仓库拉取基础镜像（需网络），靶场本身仍只绑 `127.0.0.1`、
  数据均为合成、仅用于授权隔离教学。
- Pwn 只做局部变量覆盖并调用题内 `win()`；第一道门是随机 challenge/cookie，第二道门要求同时满足 `admin` 与 `auth` 两个字段。
- Reverse 只分析本地 stripped ELF；校验包含字节置换和相邻字节链两层可逆变换。
- Forensics 的 `10.10.4.x`、`*.training.test` 均为虚构/保留用途地址，不要尝试解析或访问。

## 8. 重新生成与定制

修改某题的 `instructor/flag.txt` 后：

```bash
(cd crypto && ./generate.sh)        # 重新加密
(cd reverse && ./build.sh)           # 重新生成数据块、编译并 strip
(cd pwn && ./build.sh)               # 重新嵌入编码 flag
(cd forensics && ./generate.sh)      # 重新合成 PCAP
# Web 直接读取 flag.txt，重启服务即可
(cd web && ./stop.sh && ./start.sh 8080)
```

最后回到根目录运行统一验证，并把完整输出保存到 `verification-report.txt`：

```bash
python3 verify_all.py 2>&1 | tee verification-report.txt
```

确认 5/5 通过。

## 9. 完成情况

- 6 道题均已实现：前 5 题配套环境、题面、附件、生成/构建脚本、讲师 walkthrough 和可运行 `solve.py` 齐全；`hengyuan` 为多容器 Docker 内网靶场（service 型，4 flag）。
- Pwn 已升级为“随机 challenge/cookie + `admin`/`auth` 双字段覆盖”的本地玩具，仍只打印 flag，不生成 shell。
- Reverse 已升级为 stripped 二进制，包含字节置换和相邻字节链两层可逆校验；`solve.py` 只从公开二进制提取数据。
- 已在本机重新编译并执行 `verify_all.py`，结果 **5/5 PASS**，完整输出见 `verification-report.txt`。
- 未使用第三方 Python 依赖，未搭建计分平台，未访问真实目标，无未完成项。
