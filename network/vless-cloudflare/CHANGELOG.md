# VLESS + Cloudflare Changelog

## v1.2.0 — 2026-08-16

### Changed

- 项目正式采用长期 AI 维护结构：
  - `AGENTS.md`
  - `agent-context/CONTEXT.md`
  - `agent-context/STATE.md`
  - `agent-context/DECISIONS.md`
  - `agent-context/HISTORY.md`
  - `agent-context/ROADMAP.md`
- 部署脚本从项目根目录整理到：`scripts/deploy.sh`
- 候选域名清单从项目根目录整理到：`config/candidate-domains.txt`
- 更新 README、Raw URL、项目说明和 AI 上下文中的所有目录引用。
- 普通 `README.md` 继续面向使用者；AI / Coding Agent 维护项目前先读 `AGENTS.md`。

### Behavior

- 本版本主要是仓库结构和维护体系升级。
- VLESS / Nginx / WebSocket / 候选域名测速核心行为不主动改变。

## v1.1.1 — 2026-08-16

- 移除候选域名中的静态“推荐线路”字段。
- 候选清单简化为 `NAME | ADDRESS | INTRO`。
- `/root/vless-nodes.txt` 每个候选只保留：
  - Address
  - 域名介绍
  - VLESS 链接
- 不再预设电信 / 移动 / 联通推荐，最终以 Windows BAT 的真实下载测速结果为准。
- 保留 BAT 的实际测速排名、PRIMARY / BACKUP / BASE 输出逻辑。

## v1.1.0 — 2026-08-16

- 精简默认候选域名。
- 保留：
  - BASE
  - `cf.090227.xyz`
  - `www.visa.cn`
  - `mfa.gov.ua`
  - `www.shopify.com`
  - `store.ubi.com`
  - `staticdelivery.nexusmods.com`
- 移除“更多优选域名”中的第三方候选，包括：
  - `cloudflare-dl.byoip.top`
  - `cf.877774.xyz`
  - `saas.sin.fan`
  - `bestcf.030101.xyz`
  - `cloudflare.182682.xyz`
- Windows BAT 测速结果去掉 Type / For 等冗余字段。

## v1.0.0 — 2026-08-16

- 初始化新 VPS 一键部署脚本。
- 支持 Cloudflare + Nginx + VLESS/WebSocket。
- 自动生成 UUID、WS Path、内部端口。
- 固化实测兼容配置：
  - VLESS inbound 使用 `settings.clients`
  - WebSocket 使用 `streamSettings.network = "ws"`
  - Nginx 显式转发 WebSocket `Upgrade` / `Connection`
- 增加配置备份、基础回滚、Xray/Nginx 配置检查和本机 WebSocket 101 验证。
- 部署后自动生成：
  - `/root/deploy-info.txt`
  - `/root/vless-nodes.txt`
  - `/root/vless-candidate-domains.txt`
  - `/root/test-vless-domains.bat`
- Windows BAT 支持真实 VLESS 链路下载测速、3 轮统计、最终排名，以及 PRIMARY / BACKUP / BASE 输出。
