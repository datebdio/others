# History / Troubleshooting Notes

## 2026-08-15 - BAT 一闪而过

现象：Windows 双击安装 BAT 一闪而过，看不到错误。

原因与改进：早期脚本为 UTF-8 无 BOM 且包含中文输出，同时隐藏了部分命令错误。后续安装入口改为 ASCII `install.cmd`，失败时保留窗口并显示诊断信息。

## 2026-08-15 - Xray 黑色窗口影响使用

现象：Xray 控制台长期显示在前台，容易被手动误关。

改进：Go 正式程序使用 GUI subsystem，Xray 子进程使用 Windows `CREATE_NO_WINDOW` + `HideWindow`。

## 2026-08-16 - 程序目录自包含

早期版本安装后把程序和扩展复制到系统用户目录。用户指出这样增加一步，并且关闭自动打开的扩展文件夹后不容易再次定位。

改进：v0.2 起所有文件原地运行，安装脚本只注册当前目录 EXE 的启动项。
