# Architecture Decisions

## D001 - 浏览器扩展 + 本地 Go + Xray

Chrome 扩展本身不直接实现 VLESS/VMess/Trojan 原始传输。扩展只负责浏览器 PAC 和 UI，本地 Go 程序负责节点管理与 Xray 生命周期。

## D002 - 仅监听 loopback

管理 API 固定监听 `127.0.0.1:17890`，Xray SOCKS5 默认监听 `127.0.0.1:10808`，避免无意暴露给局域网。

## D003 - 原地运行

程序不复制到 `%LOCALAPPDATA%` 或临时目录。`install.cmd` 只注册当前目录 EXE 的开机启动、启动后台并打开当前目录的扩展文件夹。

原因：减少重复文件、让插件目录可定位、方便整体备份/迁移。

## D004 - 路径由 EXE 自身定位

Go 使用 `os.Executable()` + `filepath.Dir/Join` 定位 `core/`、`data/` 等，不依赖当前工作目录，必须兼容中文路径和空格。

## D005 - 无黑窗

正式 Go EXE 使用 Windows GUI subsystem。启动 Xray 时使用 `HideWindow` + `CREATE_NO_WINDOW`。用户不应通过关闭控制台窗口意外停止代理。

## D006 - 节点库与运行配置分离

`state.json` 保存用户节点库；`active.json` 只保存当前运行时 Xray 配置。编辑/删除节点不直接操作运行配置文件。

## D007 - 插件保持简洁

不追求完整 v2rayN 功能。主 UI 只提供日常高频操作；特殊协议/传输允许用户导入完整 Xray JSON。
