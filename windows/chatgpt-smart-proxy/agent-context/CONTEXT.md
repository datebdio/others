# Project Context

## 目标

为 Windows 上的 Chrome/Edge 提供一个比系统全局代理更轻量的浏览器分流工具。默认只让 ChatGPT/OpenAI 相关域名通过用户自己的 V2/Xray 节点，其余网站保持 DIRECT。

## 用户体验原则

- 插件界面要简单，不做成完整 v2rayN。
- 主界面只突出代理开关、当前节点、节点列表、分流模式。
- 节点复杂参数只在添加/编辑时出现。
- 整个程序目录自包含，用户解压到固定位置即可长期使用。
- 不出现长期驻留的黑色 CMD/Xray 窗口。

## 技术组成

- 浏览器扩展：Manifest V3，使用 `chrome.proxy` + PAC。
- 本地后台：Go，HTTP API `127.0.0.1:17890`。
- 本地代理：Xray SOCKS5 `127.0.0.1:10808`。
- 节点：VLESS / VMess / Trojan；复杂情况允许完整 Xray JSON。

## 数据

- `data/state.json`：节点库、当前节点、启用状态。
- `data/active.json`：当前实际交给 Xray 的配置。
- `data/xray.log`：Xray 日志。
- `data/app.log`：后台程序日志。
