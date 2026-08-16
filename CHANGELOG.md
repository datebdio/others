# Changelog

## 2026-08-16

### Repository maintenance standard

- 新增根目录 `AGENTS.md`，作为整个 `others` 仓库的 AI / Coding Agent 总入口。
- 长期维护项目统一采用：
  - `README.md`
  - `AGENTS.md`
  - `CHANGELOG.md`
  - `agent-context/`
- `agent-context/` 标准文件：
  - `CONTEXT.md`
  - `STATE.md`
  - `DECISIONS.md`
  - `HISTORY.md`
  - `ROADMAP.md`
- 新增 `templates/project-template/`，供未来新项目复制维护骨架。
- 根 README、分类 README 和项目 README 都增加 AI 阅读入口，避免新对话只读普通说明后直接修改代码。

### VLESS + Cloudflare v1.2.0

- VLESS 项目迁移到标准长期维护结构。
- `deploy.sh` 从项目根目录移动到 `scripts/deploy.sh`。
- `candidate-domains.txt` 从项目根目录移动到 `config/candidate-domains.txt`。
- 同步更新脚本中的候选域名 Raw URL、README 执行命令、目录说明和 AI 上下文。
- 新增项目自己的 `CHANGELOG.md`；后续 VLESS 详细版本记录优先维护在项目内。
- 本次版本主要是目录和长期维护体系升级，VLESS/Nginx/WebSocket/测速核心行为不主动改变。

### VLESS + Cloudflare v1.1.1

- 移除候选域名中的静态“推荐线路”字段。
- `candidate-domains.txt` 简化为：`NAME | ADDRESS | INTRO`。
- `/root/vless-nodes.txt` 每个候选只保留：
  - Address
  - 域名介绍
  - VLESS 链接
- 不再预设电信 / 移动 / 联通推荐，最终以 Windows BAT 的真实下载测速结果为准。
- 保留 BAT 的实际测速排名、PRIMARY / BACKUP / BASE 输出逻辑。

### VLESS + Cloudflare v1.1.0

- 精简默认优选域名候选。
- 保留：
  - BASE 自己的 Cloudflare 业务域名
  - `cf.090227.xyz` 站点自己的三网优选域名
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

### Initial

- 初始化 `others` 运维脚本仓库结构。
- 新增 `network/vless-cloudflare/` 模块。
- 新增新 VPS 一键部署脚本。
- 新增候选 Cloudflare 入口域名清单。
- 部署完成后自动生成：
  - `/root/deploy-info.txt`
  - `/root/vless-nodes.txt`
  - `/root/vless-candidate-domains.txt`
  - `/root/test-vless-domains.bat`
- Windows BAT 支持真实 VLESS 链路下载测速、3 轮统计、最终排名，以及 PRIMARY / BACKUP / BASE VLESS 输出。
- 固化本次实测兼容配置：
  - VLESS inbound 使用 `settings.clients`
  - WebSocket 使用 `streamSettings.network = "ws"`
  - Nginx 显式转发 WebSocket `Upgrade` / `Connection`
- 增加配置备份、基础回滚、Xray/Nginx 配置检查和本机 WebSocket 101 握手验证。
