# Changelog

## 2026-08-16

### Added

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
