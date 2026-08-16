# others

个人运维脚本、部署工具与常用命令仓库。

> 根目录 README 只作为 **总菜单 / 项目索引**。每个项目的详细说明、使用方法、参数、故障排查都放在对应子目录的 `README.md` 中。

## 快速导航

| 分类 | 说明 | 入口 |
|---|---|---|
| 🌐 网络 / 代理 | Cloudflare、VLESS、DNS、路由、测速等 | [进入 network/](network/) |
| 🖥 VPS / Linux | 新机初始化、Nginx、Docker、备份、安全等 | [进入 server/](server/) |
| 🪟 Windows | BAT、PowerShell、网络与系统工具 | [进入 windows/](windows/) |
| 🚀 部署工具 | Web、Node.js、数据库、反代等应用部署 | [进入 deployment/](deployment/) |
| 🩺 诊断工具 | 网络、服务器、连通性、性能检查 | [进入 diagnostics/](diagnostics/) |
| 🗄 归档 | 已废弃或被新版替代的旧工具 | [进入 archive/](archive/) |

## 当前项目

### 🌐 网络 / 代理

| 项目 | 功能 | 平台 | 状态 | 版本 | 入口 |
|---|---|---|---|---|---|
| VLESS + Cloudflare | 新 VPS 一键部署、Cloudflare 优选域名测速、自动生成 VLESS 节点 | Linux + Windows | 🧪 待新机完整验证 | v1.1.1 | [查看项目](network/vless-cloudflare/) |

## 状态说明

- ✅ **稳定**：已在目标环境完整验证，可作为常用版本
- 🧪 **测试中**：主要功能已完成，仍需更多实际环境验证
- 🚧 **开发中**：结构或功能尚未完成
- 🗄 **已归档**：不再维护，仅保留历史参考

## 仓库组织规则

一个完整功能作为一个独立项目目录管理。例如：

```text
network/vless-cloudflare/
├─ README.md
├─ deploy.sh
├─ candidate-domains.txt
└─ docs/
```

即使项目同时包含 Linux `.sh`、Windows `.bat`、配置文件和文档，也放在 **同一个项目目录** 中，不按文件类型拆散。

建议长期保持以下结构：

```text
others/
├─ README.md
├─ CHANGELOG.md
├─ network/
│  ├─ README.md
│  ├─ vless-cloudflare/
│  ├─ cloudflare-speedtest/
│  ├─ dns-tools/
│  └─ routing-tools/
├─ server/
│  ├─ README.md
│  ├─ vps-init/
│  ├─ nginx/
│  ├─ docker/
│  ├─ backup/
│  └─ security/
├─ windows/
│  ├─ README.md
│  ├─ network/
│  ├─ maintenance/
│  ├─ powershell/
│  └─ batch/
├─ deployment/
│  ├─ README.md
│  ├─ web/
│  ├─ nodejs/
│  ├─ database/
│  └─ reverse-proxy/
├─ diagnostics/
│  ├─ README.md
│  ├─ server-check/
│  ├─ speedtest/
│  └─ connectivity/
└─ archive/
   └─ README.md
```

## 新项目约定

以后新增工具时，原则上至少包含：

```text
project-name/
├─ README.md
└─ 主脚本或主程序
```

项目 README 建议固定包含：

1. 功能
2. 适用场景
3. 快速使用
4. 文件说明
5. 工作原理
6. 输出结果
7. 注意事项
8. 故障排查
9. 版本信息

## 安全约定

以下内容不要提交到仓库：

- Cloudflare API Token
- SSH 私钥
- Origin CA 私钥
- 服务器账户密码
- Cookie / Access Token
- 实际生产服务器的敏感实例配置

通用部署脚本可以生成 UUID、WS Path 等实例参数，但这些参数应保留在目标服务器本地，不自动回传 GitHub。

## 最近更新

- VLESS + Cloudflare 升级到 `v1.1.1`
- 默认候选域名只保留 BASE、`cf.090227.xyz` 和主要官方站点 Cloudflare 域名
- 移除“更多优选域名”中的第三方候选
- 节点说明仅保留 Address、域名介绍和 VLESS 链接
- 移除静态电信 / 移动 / 联通推荐字段
- Windows BAT 继续使用真实 VLESS 下载测速并自动排名

完整变更记录见 [CHANGELOG.md](CHANGELOG.md)。
