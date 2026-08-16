# ChatGPT Smart Proxy - Agent Instructions

本文件是本项目的 AI / Coding Agent 接管入口。

## 必读

所有修改先读：

1. `agent-context/CONTEXT.md`
2. `agent-context/STATE.md`

## 按任务类型继续读取

- 架构、代理链路、节点数据模型、Xray 生命周期：`agent-context/DECISIONS.md`
- Bug / 回归排查：搜索 `agent-context/HISTORY.md`
- 新功能 / 规划：`agent-context/ROADMAP.md`

## 修改完成后

按实际变化同步维护：

- `STATE.md`
- `DECISIONS.md`
- `HISTORY.md`
- `ROADMAP.md`
- `CHANGELOG.md`
- 用户可见行为改变时更新 `README.md`

## 项目规则

- 后台管理 API 固定只监听 `127.0.0.1:17890`，除非有明确安全设计变更。
- 浏览器侧 SOCKS5 默认使用 `127.0.0.1:10808`。
- Chrome/Edge 扩展只负责 UI、PAC 和浏览器代理状态；节点/Xray 生命周期放在 Go 后台。
- Windows 正式 EXE 使用 GUI subsystem；Xray 子进程必须无控制台窗口。
- 安装采用原地运行，不要重新引入复制到系统临时目录或 `%LOCALAPPDATA%` 的流程。
- 路径必须兼容中文和空格，禁止依赖当前工作目录。
- 不提交 `data/state.json`、真实节点、订阅 URL、密码、UUID、Token、Cookie 等敏感实例数据。
- 修改发布包后必须重新计算 SHA-256，并同步 README / CHANGELOG / STATE。
