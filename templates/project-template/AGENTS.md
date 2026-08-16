# Project Agent Instructions

本文件是该项目的 AI / Coding Agent 接管入口。

## 必读

所有修改先读：

1. `agent-context/CONTEXT.md`
2. `agent-context/STATE.md`

## 按任务类型继续读取

- 架构/核心行为修改：`agent-context/DECISIONS.md`
- Bug/回归排查：搜索 `agent-context/HISTORY.md`
- 新功能/规划：`agent-context/ROADMAP.md`

## 修改完成后

按实际变化同步维护：

- `STATE.md`
- `DECISIONS.md`
- `HISTORY.md`
- `ROADMAP.md`
- `CHANGELOG.md`
- 用户可见行为改变时更新 `README.md`

## 规则

- 先理解项目，再看代码。
- 不要未经验证推翻已有关键设计决定。
- 移动目录时同步更新所有链接、命令、Raw URL 和配置路径。
- 不提交生产密码、Token、私钥和敏感实例参数。
