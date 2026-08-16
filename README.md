# others

个人运维脚本与常用命令仓库。

这个仓库用于长期管理可复用的 VPS、Linux、Windows、网络诊断、部署与测速脚本。原则是：

- **通用脚本进 GitHub**
- **服务器实例密钥不进 GitHub**
- 每个功能单独分目录，附带 README、用途、版本和升级记录
- 能自动检测就自动检测，涉及覆盖已有配置时优先备份和回滚
- 实测优先，不把“优选”标签等同于一定更快

## 当前模块

### `network/vless-cloudflare/`

Cloudflare + Nginx + VLESS/WebSocket 新 VPS 标准部署与优选域名测速。

包含：

- `deploy.sh`：新 VPS 一键部署
- `candidate-domains.txt`：Cloudflare 候选入口域名清单
- `README.md`：完整使用说明
- `docs/architecture.md`：链路与配置逻辑

部署脚本只负责 **VPS 内部**。Cloudflare DNS、橙云和 Origin Certificate 仍由用户在 Cloudflare 后台准备。

## 目录规划

```text
others/
├─ network/
│  └─ vless-cloudflare/
├─ server/
│  ├─ linux/
│  └─ vps/
├─ windows/
│  ├─ network/
│  └─ diagnostics/
├─ diagnostics/
└─ archive/
```

后续新工具按用途继续扩展目录，不把所有脚本堆在根目录。

## 安全约定

不要提交：

- Cloudflare API Token
- SSH 私钥
- Origin CA 私钥
- 实际服务器 UUID / WS Path（除非明确准备公开）
- 账户密码、Cookie、访问令牌

仓库中的部署脚本会在 VPS 本地生成实例参数，并输出到 `/root/` 下，不会自动上传这些实例信息到 GitHub。

## 版本

变更记录见 [`CHANGELOG.md`](CHANGELOG.md)。
