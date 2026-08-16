# Project Context

> 本文件主要供 AI / Coding Agent 接管项目时读取。它记录长期稳定的项目认知、边界和用户要求，不用于替代普通 `README.md`。

## 项目定位

项目：`network/vless-cloudflare`

目标是在新 VPS 上形成一套可重复维护的：

```text
Cloudflare + Nginx + VLESS + WebSocket + TLS
```

部署流程结束后，还要生成 Windows BAT，让用户在本地通过真实 VLESS 链路测试不同 Cloudflare `Address` 的下载速度并自动排序。

## 用户真正需要的工作流

1. Cloudflare 侧由用户提前手工准备。
2. `scripts/deploy.sh` 只负责 VPS 内部。
3. 脚本自动安装/配置 Xray、Nginx、证书、UUID、WS Path 等。
4. 先用自己的业务域名作为 BASE 验证完整链路。
5. 再使用自动生成的 Windows BAT 测试候选域名。
6. 优选时只改变 `Address`。
7. `Host` / `SNI` / UUID / Path 保持当前 VPS 的业务配置不变。
8. 根据真实下载速度选择 PRIMARY / BACKUP，同时保留 BASE 兜底。

## 核心链路

```text
Windows / v2rayN
    |
    | Address = BASE 或候选 Cloudflare 域名
    | SNI     = 业务域名
    | WS Host = 业务域名
    v
Cloudflare
    v
业务域名对应的 Cloudflare zone/origin
    v
Nginx :443 on VPS
    v
WebSocket exact path
    v
Xray 127.0.0.1:10000+
    v
Internet
```

## Address / Host / SNI 的含义

- `Address`：客户端实际拨号入口，用于选择 Cloudflare 入口/路由。
- `SNI`：TLS 业务身份，始终保持用户自己的业务域名。
- `WS Host`：HTTP/WebSocket 业务 Host，始终保持用户自己的业务域名。

示例：

```text
Address = www.visa.cn
Host    = v3.example.com
SNI     = v3.example.com
```

候选域名不是“返回到业务域名”的 CNAME 逻辑；它只是客户端拨号时使用的 Cloudflare entry。Cloudflare 根据 TLS/HTTP 中的业务 hostname 继续处理业务域名的请求。

## Cloudflare 项目边界

当前项目不自动操作 Cloudflare API。

用户需要提前完成：

- 业务域名 DNS 指向 VPS
- 开启橙云
- SSL/TLS = Full (strict)
- 准备覆盖业务域名的 Cloudflare Origin Certificate 和私钥
- 将证书文件上传 VPS

除非用户未来明确要求，不要把 DNS/API Token 自动化偷偷加入部署脚本。

## 当前默认候选域名策略

默认只保留：

- BASE：用户自己的 Cloudflare 业务域名
- `cf.090227.xyz`：该优选站点自己的域名
- 一组该站列出的官方站点 Cloudflare 域名：
  - `www.visa.cn`
  - `mfa.gov.ua`
  - `www.shopify.com`
  - `store.ubi.com`
  - `staticdelivery.nexusmods.com`

用户已经手工/实际测试过“更多优选域名”，整体表现不理想，因此不要默认恢复以下或类似第三方候选：

```text
cloudflare-dl.byoip.top
cf.877774.xyz
saas.sin.fan
bestcf.030101.xyz
cloudflare.182682.xyz
```

候选清单维护在：

```text
config/candidate-domains.txt
```

## 节点说明输出要求

`/root/vless-nodes.txt` 中每个候选只需要：

```text
Address
域名介绍
VLESS 链接
```

不要加入：

```text
Type
For
Note
电信/移动/联通静态推荐
```

线路优劣以本地实际测速为准，不预设运营商结论。

## Windows BAT 目标

部署脚本生成：

```text
/root/test-vless-domains.bat
```

要求：

- 不修改用户现有 v2rayN 配置
- 自动在 v2rayN 目录中寻找 `xray.exe`
- 独立启动临时 SOCKS 端口
- 每个候选只修改 VLESS outbound 的 `address`
- `Host` / `SNI` / UUID / Path 固定
- 使用真实下载测试，而不是只测 ping/TCP
- 默认 20,000,000 bytes × 3 轮
- 输出 Average / Best / Worst / Success
- 自动排序
- 自动生成 PRIMARY / BACKUP / BASE VLESS
- BAT 要注意 Windows CMD 编码兼容，避免 UTF-8 BOM 引起第一行乱码

## 项目目录原则

当前项目保持简单但可扩展：

```text
vless-cloudflare/
├─ README.md
├─ AGENTS.md
├─ CHANGELOG.md
├─ agent-context/
├─ scripts/
│  └─ deploy.sh
├─ config/
│  └─ candidate-domains.txt
└─ docs/
   └─ architecture.md
```

以后只有真正出现需要时才新增 `tests/`、`examples/` 等目录，不为了形式创建空目录。

## 维护偏好

- 实测优先于理论标签。
- 稳定性和可回滚性重要。
- 输出尽量简洁、直接。
- 不要让用户频繁手动更换固定 IP；候选域名方案更适合长期维护。
- 修改核心链路前先读 `DECISIONS.md`。
