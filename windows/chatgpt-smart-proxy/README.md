# ChatGPT Smart Proxy

一个面向 Windows + Chromium 浏览器的轻量按域名分流代理工具。

项目由两部分组成：

- Chrome/Edge Manifest V3 扩展：负责浏览器代理总开关、分流模式和节点管理界面。
- `ChatGPTProxy.exe`：Go 编写的本地后台管理程序，负责节点库、Xray 配置生成、Xray 生命周期和 TCP 延迟测试。

默认链路：

```text
Chrome / Edge
  -> PAC 域名分流
  -> SOCKS5 127.0.0.1:10808
  -> Xray Core
  -> VLESS / VMess / Trojan 节点
```

## 当前版本

`v0.2.0`

主要能力：

- 仅 ChatGPT/OpenAI、常用 AI 网站、浏览器全局三种分流模式。
- VLESS / VMess / Trojan 链接导入。
- 完整 Xray JSON 导入。
- 多节点添加、选择、编辑、删除、启用/停止。
- 节点 TCP 延迟测试。
- Go 后台和 Xray 均无黑色控制台窗口。
- 整个程序原地运行，不复制到 `%LOCALAPPDATA%`。
- 支持安装目录包含中文和空格。

## 快速使用

1. 从 [`releases/`](releases/) 下载当前 ZIP 并解压到准备长期使用的位置。
2. 双击 `install.cmd`。
3. Chrome 打开 `chrome://extensions/`。
4. 开启“开发者模式”，点击“加载已解压的扩展程序”。
5. 选择安装脚本自动打开的 `extension` 文件夹。
6. 在扩展中添加节点并开启代理。

程序运行后：

- 管理 API：`127.0.0.1:17890`
- Xray SOCKS5：`127.0.0.1:10808`
- 用户节点数据：程序目录下 `data/state.json`
- 当前 Xray 运行配置：`data/active.json`
- 日志：`data/app.log`、`data/xray.log`

> `data/` 中可能包含节点 UUID、密码和完整连接参数，不要提交真实用户数据到仓库。

## 目录

```text
chatgpt-smart-proxy/
├─ README.md
├─ AGENTS.md
├─ CHANGELOG.md
├─ install.cmd
├─ extension/                 # 浏览器扩展源码
├─ src/companion/             # Go 后台源码
├─ licenses/                  # 第三方许可证
├─ releases/                  # 已测试的 Windows 成品包
└─ agent-context/             # 长期维护上下文
```

正式 ZIP 内另外包含 Xray Core、GeoIP/GeoSite 数据和编译好的 `ChatGPTProxy.exe`。

## 开发

Go 后台：

```bash
cd src/companion
go test ./...
```

编译 Windows x64 GUI 版本：

```bash
GOOS=windows GOARCH=amd64 go build -ldflags="-H=windowsgui" -o ChatGPTProxy.exe .
```

`process_windows.go` 会为 Xray 子进程设置 `HideWindow` 和 `CREATE_NO_WINDOW`，避免 Xray 弹出控制台窗口。

## 安全边界

- 本地管理 API 只监听 `127.0.0.1`。
- 浏览器跨域访问只允许 `chrome-extension://` Origin。
- 不在仓库中保存实际节点、订阅地址、Token、Cookie 或其他生产密钥。
- 本项目只负责用户自行配置的网络代理和浏览器分流，不包含绕过账号限制、风控或服务端保护措施的功能。

## Release 校验

`releases/ChatGPT-Smart-Proxy-v0.2.0-Windows-x64.zip`

以 `releases/SHA256SUMS.txt` 为准。
