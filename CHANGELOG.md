# Changelog

## 2026-08-16

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
- `candidate-domains.txt` 简化为：`NAME | ADDRESS | INTRO | RECOMMEND`。
- `/root/vless-nodes.txt` 中每个候选只额外显示：
  - 域名介绍
  - 推荐线路（电信/移动/联通）
- Windows BAT 测速结果去掉 Type / For 等冗余字段，继续保留真实 VLESS 下载测速、3 轮统计、最终排名和 PRIMARY / BACKUP / BASE 输出。

### Initial

- 初始化 `others` 运维脚本仓库结构。
- 新增 `network/vless-cloudflare/` 模块。
- 新增新 VPS 一键部署脚本 `deploy.sh`。
- 新增候选 Cloudflare 入口域名清单 `candidate-domains.txt`。
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
