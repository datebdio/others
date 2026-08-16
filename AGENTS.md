# Repository Agent Instructions

本文件是 `others` 仓库的 AI / Coding Agent 总入口。

如果任务涉及修改、升级、重构、排查或继续维护仓库中的任一项目，请先执行本文件中的阅读流程，再动代码。

## 1. 先确定目标项目

不要在仓库根目录直接猜测应该修改哪些文件。

先定位具体项目目录，例如：

```text
network/vless-cloudflare/
```

分类目录的 `README.md` 主要是菜单，不是项目维护上下文。

## 2. 进入项目后优先读取项目 `AGENTS.md`

每个长期维护项目应包含：

```text
README.md
AGENTS.md
CHANGELOG.md
agent-context/
```

其中：

- `README.md`：主要给人看，说明项目是什么、怎么用。
- `AGENTS.md`：AI 接管该项目的阅读路由与维护规则。
- `CHANGELOG.md`：该项目面向版本的更新记录。
- `agent-context/`：项目长期维护上下文，主要给 AI / Agent 使用。

如果项目存在自己的 `AGENTS.md`，项目级规则优先于本文件中更宽泛的规则。

## 3. 不要无差别读取所有历史

项目级 `AGENTS.md` 会告诉你根据任务类型读取哪些上下文。

通常：

- 所有修改：读 `agent-context/CONTEXT.md` + `agent-context/STATE.md`
- 架构/核心行为修改：再读 `agent-context/DECISIONS.md`
- Bug / 回归排查：搜索 `agent-context/HISTORY.md` 中相关记录
- 新功能 / 规划：再读 `agent-context/ROADMAP.md`

先理解项目，再看代码；不要只读代码后猜测为什么这样实现。

## 4. 修改完成后同步维护上下文

代码修改和项目记忆必须一起维护。

至少检查：

- `agent-context/STATE.md` 是否仍准确
- 是否产生新的关键设计决定，需要更新 `DECISIONS.md`
- 是否出现以后可能重复踩的坑，需要更新 `HISTORY.md`
- 是否改变后续计划，需要更新 `ROADMAP.md`
- 是否需要更新项目 `CHANGELOG.md`
- 如果是仓库级重大变化，再更新根目录 `CHANGELOG.md`

## 5. 目录与引用必须同步

移动或重命名文件时，必须搜索并同步更新：

- README 中的链接和命令
- 脚本内的 GitHub Raw URL
- 配置路径
- 文档中的目录结构
- AGENTS / agent-context 中的关键文件路径
- 模板中的示例路径

不要只移动文件而留下旧路径。

## 6. 安全约定

不要把以下内容提交到仓库：

- 密码
- API Token / Access Token
- SSH 私钥
- TLS / Origin 私钥
- Cookie
- 生产环境密钥
- 服务器实例敏感配置

通用脚本可以在目标机器本地生成 UUID、随机 Path 等实例参数，但不要自动回传仓库。

## 7. 新项目标准

新增长期维护项目时，优先从：

```text
templates/project-template/
```

复制项目维护骨架，再按项目实际复杂度增加：

```text
scripts/
config/
docs/
tests/
examples/
src/
assets/
```

不要为了统一外观创建大量无实际内容的空目录。
