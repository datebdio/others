# Current State

> 本文件是 AI 接管项目时的当前现场快照，应保持简短、准确、及时更新。

```text
project: vless-cloudflare
version: 1.2.0
status: testing
last_updated: 2026-08-16
```

## 当前代码位置

```text
scripts/deploy.sh
config/candidate-domains.txt
docs/architecture.md
```

## 当前功能

已实现：

- Debian / Ubuntu VPS 内部部署
- Xray 安装与独立系统用户
- VLESS + WebSocket inbound
- Nginx 443 TLS + WebSocket 反代
- Cloudflare Origin Certificate 文件接入
- 自动 UUID
- 自动随机 WS Path
- 自动选择 10000-10100 内部端口
- Xray 配置测试
- `nginx -t`
- systemd 启动/开机启动
- 本机 HTTPS 200 验证
- 本机 WebSocket 101 验证
- 失败时尽量恢复已有配置备份
- 自动生成 BASE + 候选 VLESS
- 自动生成 Windows 域名测速 BAT
- BAT 真实下载 3 轮统计和排序
- 自动输出 PRIMARY / BACKUP / BASE

## 已实际验证的核心兼容方案

- VLESS 服务端 inbound：`settings.clients`
- WebSocket：`streamSettings.network = "ws"`
- Nginx 显式转发 `Upgrade` / `Connection`
- Xray 配置文件需要让实际 service user/group 可读
- 客户端候选域名只改变 `Address`
- `Host` / `SNI` 保持业务域名
- Windows BAT 的临时 VLESS outbound 使用 `settings.vnext[].users[]`

## 当前仍需验证

### P0

当前 GitHub `scripts/deploy.sh` 的最新整理版本尚未在一台完全干净的新 VPS 上从零完整跑完一轮。

需要确认：

1. Debian 新机完整执行
2. Ubuntu 新机完整执行
3. Xray 官方安装器创建/修改 systemd 服务后的用户权限
4. Nginx 与默认站点/已有 443 的冲突处理
5. 自动生成的 `/root/test-vless-domains.bat` 在当前 v2rayN 版本下完整运行
6. BASE 实际联网
7. 候选域名实际联网及排名输出
8. 失败回滚是否符合预期

## 当前候选

```text
BASE
cf.090227.xyz
www.visa.cn
mfa.gov.ua
www.shopify.com
store.ubi.com
staticdelivery.nexusmods.com
```

不维护静态运营商推荐。

## 当前输出文件

目标 VPS：

```text
/root/deploy-info.txt
/root/vless-nodes.txt
/root/vless-candidate-domains.txt
/root/test-vless-domains.bat
```

Windows BAT 同目录输出：

```text
domain_speed_results.csv
recommended_vless.txt
```

## 当前优先级

1. 完成干净 VPS 全流程验证
2. 根据第一次真实部署结果修复兼容问题
3. 验证生成 BAT 与最新目录结构无引用错误
4. 验证通过后再考虑把状态从 `testing` 改为 `stable`

## Do Not Regress

- 不要恢复已经移除的“更多优选域名”作为默认候选
- 不要重新添加运营商静态推荐字段
- 不要未经完整测试把服务端 `clients` 改成 `users`
- 不要未经完整测试把 `network: "ws"` 改成其他新语法
- 不要把 Cloudflare API 操作塞入当前一键部署主流程
- 不要把真实服务器 UUID、WS Path、证书私钥提交到仓库
