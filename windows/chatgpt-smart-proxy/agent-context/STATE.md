# Current State

## Version

- 当前版本：`v0.2.0`
- 平台：Windows x64
- Go module：`chatgptproxy`

## 已实现

- Chrome/Edge Manifest V3 扩展。
- PAC 三种模式：ChatGPT/OpenAI、常用 AI、浏览器全局。
- 多节点节点库。
- VLESS / VMess / Trojan / 完整 Xray JSON。
- 节点添加、选择、编辑、删除。
- 代理总开关与 Xray 生命周期联动。
- TCP 延迟测试。
- Go GUI subsystem + Xray `CREATE_NO_WINDOW`。
- 安装目录原地运行，兼容中文和空格路径。
- 当前用户数据与发布文件隔离。

## 验证状态

- Go 单元测试通过。
- Go 源码可交叉编译 Windows amd64 GUI EXE。
- 开发阶段已使用同系列 Xray 完成：添加节点、切换、编辑当前节点、删除当前节点、SOCKS5 握手、停止代理等本地联调。
- `v0.1.1` 安装流程已在真实 Windows 用户环境测试通过。
- `v0.2.0` 已形成正式 Windows x64 发布包，后续实际 Windows 使用反馈继续记录到 HISTORY。

## Release

- 文件：`releases/ChatGPT-Smart-Proxy-v0.2.0-Windows-x64.zip`
- SHA-256：以 `releases/SHA256SUMS.txt` 为准。
