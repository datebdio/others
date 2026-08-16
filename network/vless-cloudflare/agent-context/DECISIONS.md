# Architecture Decisions

> 这里记录“为什么这样做”。修改核心架构、协议、部署边界或测速逻辑前必须先读本文件。

## D-001 — Cloudflare 侧保持人工准备

**Status:** Active  
**Date:** 2026-08-16

### Decision

`scripts/deploy.sh` 只负责 VPS 内部，不调用 Cloudflare API 自动创建/修改 DNS、SSL 模式或证书。

### Why

当前目标是把服务器侧流程稳定下来，避免把 Cloudflare Token、账户权限和 DNS 自动化耦合进主脚本。

### Change only if

用户明确要求增加 Cloudflare API 自动化，并单独设计凭据安全、权限范围和回滚方案。

---

## D-002 — Nginx 终止 TLS，Xray 只监听 localhost

**Status:** Active

### Decision

```text
Cloudflare -> Nginx :443 -> Xray 127.0.0.1:10000+
```

Cloudflare Origin Certificate 配置在 Nginx；Xray inbound 使用 `security: none`，只接受本机 Nginx 反代。

### Why

这与当前已经跑通的 Cloudflare + WSS 架构一致，也避免直接把内部 VLESS listener 暴露到公网。

---

## D-003 — VLESS 服务端 inbound 使用 `settings.clients`

**Status:** Active

### Decision

服务端使用：

```json
"settings": {
  "clients": [
    {"id": "UUID"}
  ],
  "decryption": "none"
}
```

### Why

实际服务器曾把 inbound 写成 `users`，配置虽然可进入运行流程，但实际连接出现：

```text
proxy/vless/encoding: invalid request user id
```

改回 `clients` 后 VLESS 鉴权恢复正常。

### Important distinction

Windows 临时客户端 Xray outbound 中：

```text
settings.vnext[].users[]
```

是客户端 outbound 的正确结构，不要因为服务端使用 `clients` 而把客户端 outbound 也机械改掉。

### Change only if

在目标 Xray 版本上完成配置测试、WebSocket 101、真实 VLESS 鉴权和实际下载全链路验证。

---

## D-004 — WebSocket 使用 `streamSettings.network = "ws"`

**Status:** Active

### Decision

使用：

```json
"streamSettings": {
  "network": "ws",
  "security": "none",
  "wsSettings": {
    "path": "/..."
  }
}
```

### Why

实际服务器曾尝试类似 `method: "websocket"` 的新表示方式，出现 Cloudflare 502、Xray `invalid request version`、Nginx upstream 提前关闭。

改回 `network: "ws"` 后本地和 Cloudflare 路径都恢复 `101 Switching Protocols`。

### Change only if

新写法在实际目标环境完成完整回归测试，不允许只因为上游文档变更就直接替换。

---

## D-005 — 候选域名只改变 Address

**Status:** Active

### Decision

候选节点只替换：

```text
Address
```

保持：

```text
Host = 业务域名
SNI  = 业务域名
UUID = 当前 VPS UUID
Path = 当前 VPS WS Path
```

### Why

候选域名的作用是选择客户端拨号的 Cloudflare entry；业务身份仍由 TLS SNI 和 WS Host 指向自己的 Cloudflare hostname。

不要把这个逻辑描述为“候选域名 CNAME 回到业务域名”。

---

## D-006 — 默认候选保持精简

**Status:** Active

### Decision

默认候选只保留：

- BASE
- `cf.090227.xyz`
- 当前选定的官方站点 Cloudflare 域名

不默认加入该网站“更多优选域名”中的第三方维护域名。

### Why

用户已经进行过实际/手工测试，这些额外域名总体表现不理想或不可用。长期策略是少量候选 + 真实 VLESS 下载测速，而不是堆大量理论“优选”域名。

### Related output decision

候选域名不维护静态“电信/移动/联通推荐”，因为线路表现具有时间和网络环境依赖性。

---

## D-007 — Windows BAT 使用真实 VLESS 下载结果排名

**Status:** Active

### Decision

最终选线以真实 VLESS 链路下载为准，默认每候选：

```text
20,000,000 bytes × 3 rounds
```

统计：

```text
Average
Best
Worst
Success
```

并自动生成 PRIMARY / BACKUP / BASE。

### Why

DNS 解析、ping、TCP connect 或裸 CloudflareSpeedTest 不能完整覆盖 VLESS + TLS + WS + Cloudflare + origin 的真实路径。

### Ranking preference

长期主用不只看峰值，优先考虑：

1. 3/3 成功
2. Average
3. Worst
4. 波动

---

## D-008 — 项目采用 `AGENTS.md + agent-context/` 长期维护结构

**Status:** Active  
**Date:** 2026-08-16

### Decision

项目使用：

```text
README.md        -> 给人看的使用入口
AGENTS.md        -> AI / Agent 接管入口
CHANGELOG.md     -> 版本更新记录
agent-context/   -> AI 长期项目上下文
```

主程序和配置从项目根目录整理到：

```text
scripts/
config/
```

### Why

目标是让全新的 AI 对话不依赖聊天历史，也能先读取项目规则和长期上下文，然后安全继续升级。
