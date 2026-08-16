# 🌐 Network / 网络与代理

[← 返回仓库首页](../README.md)

> **AI / Coding Agent：** 如果要修改本分类中的具体项目，请先阅读仓库根目录 [`AGENTS.md`](../AGENTS.md)，然后进入目标项目并读取该项目自己的 `AGENTS.md`。本页只是分类菜单。

这里存放网络、代理、Cloudflare、DNS、路由、测速等相关项目。

## 项目列表

| 项目 | 功能 | 状态 | 版本 | 入口 |
|---|---|---|---|---|
| VLESS + Cloudflare | 新 VPS 一键部署、候选域名测速、VLESS 节点输出 | 🧪 测试中 | v1.2.0 | [进入项目](vless-cloudflare/) |

## 计划分类

后续可继续增加：

- `cloudflare-speedtest/`：Cloudflare IP / 域名测速
- `dns-tools/`：DNS 查询、解析检查、批量测试
- `routing-tools/`：路由、延迟、链路分析
- `proxy-tools/`：代理相关辅助工具

## 项目组织原则

一个功能尽量作为完整项目独立管理，不把同一项目的 `.sh`、`.bat`、配置文件拆到不同一级目录。

长期维护项目统一包含：

```text
README.md
AGENTS.md
CHANGELOG.md
agent-context/
```

项目内部再根据实际需要增加 `scripts/`、`config/`、`docs/`、`tests/` 等目录。
