# others

个人运维脚本、部署工具与常用命令仓库。

> **AI / Coding Agent：** 如果你准备修改、升级、重构或排查本仓库中的项目，请先阅读 [`AGENTS.md`](AGENTS.md)。不要只根据普通 README 或代码直接开始。

根目录 README 主要作为 **总菜单 / 项目索引**。每个项目的详细使用方法放在项目 `README.md`；长期维护上下文由项目 `AGENTS.md` + `agent-context/` 管理。

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
| VLESS + Cloudflare | 新 VPS 一键部署、Cloudflare 候选域名测速、自动生成 VLESS 节点 | Linux + Windows | 🧪 待新机完整验证 | v1.2.0 | [查看项目](network/vless-cloudflare/) |

## 状态说明

- ✅ **稳定**：已在目标环境完整验证，可作为常用版本
- 🧪 **测试中**：主要功能已完成，仍需更多实际环境验证
- 🚧 **开发中**：结构或功能尚未完成
- 🗄 **已归档**：不再维护，仅保留历史参考

## 仓库维护体系

长期维护项目统一采用：

```text
project-name/
├─ README.md                 # 给人看的使用说明
├─ AGENTS.md                 # AI / Coding Agent 接管入口
├─ CHANGELOG.md              # 项目版本更新记录
├─ agent-context/            # AI 长期项目上下文
│  ├─ CONTEXT.md
│  ├─ STATE.md
│  ├─ DECISIONS.md
│  ├─ HISTORY.md
│  └─ ROADMAP.md
└─ ...                       # 按项目需要增加实际目录
```

### 文件职责

- `README.md`：是什么、怎么安装、怎么使用、输出是什么。
- `AGENTS.md`：告诉 AI 修改前应该读哪些长期上下文，并规定维护流程。
- `CHANGELOG.md`：版本发生了什么变化。
- `agent-context/CONTEXT.md`：长期稳定的项目目标、边界、用户要求、核心关系。
- `agent-context/STATE.md`：当前版本、当前状态、已验证/未验证内容、当前优先级。
- `agent-context/DECISIONS.md`：重要设计决定以及为什么这样做。
- `agent-context/HISTORY.md`：以后维护者容易重复踩的故障、兼容性坑和解决经验。
- `agent-context/ROADMAP.md`：后续计划和明确不做的内容。

AI 不需要每次无差别读完整历史。项目自己的 `AGENTS.md` 会按任务类型把 AI 路由到需要的文件。

## 目录规划原则

仓库一级目录按用途分类：

```text
others/
├─ README.md
├─ AGENTS.md
├─ CHANGELOG.md
├─ templates/
│  └─ project-template/
├─ network/
├─ server/
├─ windows/
├─ deployment/
├─ diagnostics/
└─ archive/
```

每个完整功能作为一个独立项目，不把同一个项目的 `.sh`、`.bat`、配置和文档拆到不同一级目录。

项目内部根据实际需要增加：

```text
scripts/
config/
docs/
tests/
examples/
src/
assets/
```

但**不为了统一外观创建大量空目录**。

例如当前 VLESS 项目：

```text
network/vless-cloudflare/
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

## 新项目约定

新增需要长期维护的项目时，优先参考：

[`templates/project-template/`](templates/project-template/)

最低维护骨架建议包含：

```text
README.md
AGENTS.md
CHANGELOG.md
agent-context/
```

然后再按项目实际复杂度增加代码/脚本目录。

## 安全约定

以下内容不要提交到仓库：

- Cloudflare API Token
- SSH 私钥
- Origin CA 私钥
- 服务器账户密码
- Cookie / Access Token
- 真实生产服务器的敏感实例配置

通用部署脚本可以在目标机器本地生成 UUID、WS Path 等实例参数，但这些参数应保留在目标机器，不自动回传 GitHub。

## 最近更新

- 建立仓库级 [`AGENTS.md`](AGENTS.md) 作为 AI / Coding Agent 总入口
- 建立 `agent-context/` 长期项目记忆规范
- 增加 [`templates/project-template/`](templates/project-template/) 新项目模板
- VLESS + Cloudflare 升级到 `v1.2.0` 并迁移到标准目录结构
- VLESS 部署脚本移动到 `scripts/deploy.sh`
- VLESS 候选域名清单移动到 `config/candidate-domains.txt`

完整仓库级变更记录见 [`CHANGELOG.md`](CHANGELOG.md)。
