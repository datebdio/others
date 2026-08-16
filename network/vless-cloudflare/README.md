# VLESS + Cloudflare 新 VPS 标准部署

> **AI / Coding Agent：** 如果任务涉及修改、升级、重构或排查本项目，请先阅读 [`AGENTS.md`](AGENTS.md)。不要只根据本 README 或脚本直接开始。

目录：`network/vless-cloudflare/`

当前版本：**v1.2.0**

状态：**🧪 测试中，待全新 VPS 完整验证**

## 功能

把新 VPS 固定成一套可重复的：

```text
Client
  -> Cloudflare entry (Address)
  -> TLS SNI / WS Host = 业务域名
  -> Cloudflare
  -> Nginx :443
  -> WebSocket
  -> Xray 127.0.0.1:10000+
```

部署完成后：

1. 先使用自己的业务域名作为 `Address` 验证 BASE。
2. 再把自动生成的 BAT 复制到 Windows v2rayN 目录测速。
3. BAT 只改变 `Address`，UUID / Path / Host / SNI 不变。
4. 根据真实下载速度选 PRIMARY / BACKUP。
5. 保留 BASE 作为故障排查与兜底。

## 项目目录

```text
vless-cloudflare/
├─ README.md
├─ AGENTS.md
├─ CHANGELOG.md
├─ agent-context/
│  ├─ CONTEXT.md
│  ├─ STATE.md
│  ├─ DECISIONS.md
│  ├─ HISTORY.md
│  └─ ROADMAP.md
├─ scripts/
│  └─ deploy.sh
├─ config/
│  └─ candidate-domains.txt
└─ docs/
   └─ architecture.md
```

普通使用主要看本 README；AI / Agent 长期维护规则见 `AGENTS.md` 和 `agent-context/`。

## Cloudflare 前置准备

脚本只负责 **VPS 内部**，不调用 Cloudflare API。

运行前先完成：

1. Cloudflare 创建业务域名，例如 `v3.example.com`。
2. A 记录指向 VPS IP。
3. 开启橙云。
4. SSL/TLS 使用 **Full (strict)**。
5. 创建覆盖业务域名的 Cloudflare Origin Certificate。
6. 上传到 VPS，例如：

```text
/root/origin.crt
/root/origin.key
```

## 一键执行

当前脚本路径：

```text
scripts/deploy.sh
```

新 VPS 上可以直接：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/datebdio/others/main/network/vless-cloudflare/scripts/deploy.sh)"
```

按提示输入：

```text
Business domain
Origin certificate path
Origin private key path
```

也可以先下载脚本，再执行：

```bash
bash scripts/deploy.sh v3.example.com /root/origin.crt /root/origin.key
```

## 脚本会做什么

- 支持 Debian / Ubuntu
- 安装 Nginx、curl、openssl 等依赖
- 使用 XTLS 官方安装器安装/升级 Xray
- 创建独立 Xray 系统用户
- 自动生成 UUID
- 自动生成随机 WebSocket Path
- 自动选择 `10000-10100` 的空闲内部端口
- 写入 VLESS + WebSocket 配置
- 配置 Nginx 443 + TLS + WebSocket 反代
- 验证证书与私钥
- Xray 配置检查
- `nginx -t`
- systemd 启动与开机启动
- 本机 HTTPS 200 测试
- 本机 WebSocket 101 测试
- 读取 `config/candidate-domains.txt` 生成候选 VLESS 节点
- 生成 Windows 自动测速 BAT
- 已有配置先备份，部署失败尽量恢复

## 固定 Xray 配置

当前项目使用已经实际验证过的服务端配置方向：

```json
"settings": {
  "clients": [
    {
      "id": "UUID"
    }
  ],
  "decryption": "none"
},
"streamSettings": {
  "network": "ws",
  "security": "none",
  "wsSettings": {
    "path": "/random-path"
  }
}
```

即：

```text
VLESS inbound -> settings.clients
WebSocket     -> streamSettings.network = "ws"
```

这些核心兼容决策的原因记录在：

[`agent-context/DECISIONS.md`](agent-context/DECISIONS.md)

## 部署输出

成功后 VPS 本地生成：

```text
/root/deploy-info.txt
/root/vless-nodes.txt
/root/vless-candidate-domains.txt
/root/test-vless-domains.bat
```

### `vless-nodes.txt`

每个候选节点只保留必要说明：

```text
[节点名称]
Address  : 域名
域名介绍 : 简单介绍

vless://...
```

不输出 Type / For / Note，也不维护静态“推荐线路”字段。

### `test-vless-domains.bat`

复制到 Windows 的 v2rayN 目录运行。

BAT 会：

- 自动寻找 `xray.exe`
- 每个候选域名启动独立临时 Xray SOCKS
- 只替换 VLESS `Address`
- 真实下载 Cloudflare Speed 测试文件
- 默认每个域名 20,000,000 bytes × 3 次
- 输出 Average / Best / Worst / Success
- 最终按平均 MB/s 排名
- 自动输出 PRIMARY / BACKUP / BASE VLESS

当前默认 7 个候选，理论测速流量约：

```text
7 × 20 MB × 3 = 420 MB
```

可在生成的 BAT 顶部调整：

```bat
set "TEST_BYTES=20000000"
set "ROUNDS=3"
```

## Address / Host / SNI

优选时只改：

```text
Address
```

以下保持不变：

```text
Host = 业务域名
SNI  = 业务域名
UUID = 当前服务器 UUID
Path = 当前服务器 Path
```

例如：

```text
Address = www.visa.cn
Host    = v3.example.com
SNI     = v3.example.com
```

更完整的链路说明见：

[`docs/architecture.md`](docs/architecture.md)

## 候选域名策略

候选清单现在统一维护在：

[`config/candidate-domains.txt`](config/candidate-domains.txt)

当前保留：

| 名称 | Address | 域名介绍 |
|---|---|---|
| BASE | 业务域名 | 自己的 Cloudflare 原始入口和兜底 |
| CF090227 | `cf.090227.xyz` | 优选站点自己的三网优选域名 |
| VISA | `www.visa.cn` | Visa 中国官网 Cloudflare 域名 |
| MFA | `mfa.gov.ua` | 乌克兰外交部官网 Cloudflare 域名 |
| SHOPIFY | `www.shopify.com` | Shopify 官网 Cloudflare 域名 |
| UBISOFT | `store.ubi.com` | Ubisoft 官方商店 Cloudflare 域名 |
| NEXUS | `staticdelivery.nexusmods.com` | NexusMods 静态资源 Cloudflare 域名 |

已经移除“更多优选域名”中的第三方默认候选，因为实际使用/手工测试整体表现不理想。

不再给候选域名预设电信 / 移动 / 联通推荐，最终以 BAT 在当前网络的真实下载结果为准。

来源站点：

```text
https://cf.090227.xyz/
```

“官方站点域名”只表示这些 hostname 属于对应品牌/机构并使用 Cloudflare，不表示品牌方或 Cloudflare 为 VLESS/代理用途提供或背书服务。

## 选节点原则

长期主用建议优先：

1. `Success = 3/3`
2. Average MB/s
3. Worst MB/s
4. 波动大小
5. 延迟

例如：

```text
A: 3.20 / 3.18 / 3.22 MB/s
B: 4.80 / timeout / 1.20 MB/s
```

长期主用通常优先 A。

## 安全

不要提交：

```text
origin.key
deploy-info.txt
vless-nodes.txt
test-vless-domains.bat
```

实例 UUID、WS Path、证书私钥等只保留在目标 VPS 本地。

## 维护与版本

项目版本更新记录：

[`CHANGELOG.md`](CHANGELOG.md)

AI / Coding Agent 当前状态与长期维护上下文：

[`AGENTS.md`](AGENTS.md)

```text
agent-context/
```

候选域名具有时效性。以后优先更新：

```text
config/candidate-domains.txt
```

如果 Xray / Nginx 上游配置发生变化，必须先在测试 VPS 验证 HTTPS 200、WebSocket 101、VLESS 鉴权和真实下载全部正常，再升级核心配置。
