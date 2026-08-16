# Roadmap

> 本文件用于记录项目下一步方向和明确边界。规划可调整，但修改前应先确认当前 `STATE.md`。

## P0 — 当前必须完成

- 在一台全新 Debian VPS 上从零完整执行 `scripts/deploy.sh`
- 在一台全新 Ubuntu VPS 上至少完成一次完整验证
- 验证 Cloudflare Full (strict) + Origin Certificate 回源
- 验证本机 HTTPS 200
- 验证 WebSocket 101
- 验证 BASE VLESS 实际联网
- 验证自动生成的 Windows BAT 在当前 v2rayN/Xray 环境可完整运行
- 验证候选域名 3 轮测速、CSV、PRIMARY/BACKUP/BASE 输出
- 验证部署失败回滚行为

完成以上内容后，再考虑把项目状态从 `testing` 改为 `stable`。

## P1 — 可能的后续增强

仅在用户有明确需求时推进：

- 增加更清晰的 `upgrade` 模式，避免重复部署破坏已有实例
- 增加独立 `uninstall` / restore 工具
- 更明确处理 VPS 已有 Nginx / 443 服务的场景
- 增加部署前环境诊断与冲突报告
- 增加脚本自身版本检查
- 增加更明确的自动化测试脚本，而不是只依赖部署过程中的内联检查

## P2 — 候选域名维护

- 保持 `config/candidate-domains.txt` 精简
- 只在有实际依据时增加/删除候选
- 优先记录来源和用户实测情况
- 不恢复“为了数量更多”而堆大量第三方候选的做法

## Not Planned / 当前不做

除非用户明确改变项目边界，否则当前不做：

- 自动登录 Cloudflare
- 自动创建/修改 Cloudflare DNS
- 在仓库保存 Cloudflare API Token
- 自动生成或上传 Origin 私钥到 GitHub
- 预设电信/移动/联通推荐线路
- 自动长期监控候选域名
- 为了追新语法而主动替换当前已验证的 Xray 核心配置

## 结构扩展原则

当前项目只保留实际有内容的：

```text
scripts/
config/
docs/
agent-context/
```

以后确实出现内容时再增加：

```text
tests/
examples/
```

不要建立大量空目录。
