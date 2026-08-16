# VLESS + Cloudflare — Agent Instructions

本文件是本项目的 AI / Coding Agent 接管入口。

如果任务涉及修改、升级、重构、排查、扩展或继续维护本项目，请不要只根据普通 `README.md` 或代码直接开始。

## 必读顺序

所有修改先读：

1. [`agent-context/CONTEXT.md`](agent-context/CONTEXT.md)
2. [`agent-context/STATE.md`](agent-context/STATE.md)

然后根据任务类型继续：

### 修改架构、协议、Xray、Nginx、Cloudflare 链路或 BAT 核心行为

继续读：

3. [`agent-context/DECISIONS.md`](agent-context/DECISIONS.md)

### 排查 Bug、兼容性问题、回归或以前踩过的坑

在下面文件中搜索相关关键词：

4. [`agent-context/HISTORY.md`](agent-context/HISTORY.md)

### 规划新功能、改变边界或安排后续版本

继续读：

5. [`agent-context/ROADMAP.md`](agent-context/ROADMAP.md)

## 当前项目关键文件

```text
README.md
CHANGELOG.md
scripts/deploy.sh
config/candidate-domains.txt
docs/architecture.md
agent-context/
```

## 修改规则

- 先理解 `CONTEXT.md` 和当前 `STATE.md`，再修改代码。
- 不要因为上游文档出现新写法，就未经实际验证替换已经跑通过的核心配置。
- 修改路径或目录时，要同步搜索并更新 README、脚本 Raw URL、文档和 agent-context。
- 候选域名策略以用户实际使用结果为准，不要自行恢复已移除的第三方“更多优选域名”。
- 不要自行加入电信 / 移动 / 联通静态推荐字段。
- 服务器实例 UUID、WS Path、证书私钥等不得提交 GitHub。

## 修改完成后

至少检查并按需更新：

- `agent-context/STATE.md`
- `agent-context/DECISIONS.md`
- `agent-context/HISTORY.md`
- `agent-context/ROADMAP.md`
- `CHANGELOG.md`
- 用户可见行为改变时更新 `README.md`

如果产生新的故障或解决方法，只有在“未来维护者很可能再次踩坑”时才写入 `HISTORY.md`，不要把它变成普通提交日志。
