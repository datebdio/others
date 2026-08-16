# Changelog

## v0.2.0 - 2026-08-16

- 改为程序目录原地运行，不再复制到系统目录。
- 安装入口收敛为 `install.cmd`。
- Go 后台和 Xray 改为无控制台窗口运行。
- 新增多节点管理：添加、选择、编辑、删除。
- 新增代理总开关与 Xray 启停联动。
- 新增节点 TCP 延迟测试。
- 节点数据改为 `data/state.json`，运行配置独立为 `data/active.json`。
- Chrome 扩展继续支持仅 ChatGPT/OpenAI、常用 AI、浏览器全局三种分流模式。
- 发布 Windows x64 成品 ZIP。
- 增加 GitHub Actions 可复现打包流程，固定 Xray v26.3.27 并校验上游 ZIP SHA-256。

## v0.1.1 - 2026-08-15

- 修复 Windows 批处理可能受中文/代码页影响的问题。
- 安装脚本改为 ASCII 命令并保留失败窗口，增加诊断能力。

## v0.1.0 - 2026-08-15

- 建立 Chrome Manifest V3 + Go 本地后台 + Xray 的最小可用链路。
- 支持 VLESS / VMess / Trojan 和完整 Xray JSON。
- 支持 ChatGPT/OpenAI 按域名代理。
