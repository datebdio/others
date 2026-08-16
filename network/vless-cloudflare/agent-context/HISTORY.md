# Maintenance History

> 本文件不是普通 CHANGELOG。只记录未来维护者/AI 很可能再次踩到的故障、兼容性坑和关键排查经验。

## 2026-08-16 — WebSocket 新写法导致 502

### Symptom

Cloudflare 路径返回 502；Nginx 记录 upstream 提前关闭；Xray 出现：

```text
invalid request version
```

### Cause

服务端 WebSocket 配置曾尝试使用类似：

```text
method = websocket
```

而不是当前机器实际可用的：

```json
"network": "ws"
```

### Resolution

恢复：

```json
"streamSettings": {
  "network": "ws"
}
```

之后本地 WebSocket 和经 Cloudflare 的测试都恢复 `101 Switching Protocols`。

### Lesson

不要只根据新文档字段直接重写已验证生产配置；需要做真实兼容测试。

---

## 2026-08-16 — Xray 配置文件权限导致 service 无法读取

### Symptom

Xray 新服务无法正常读取配置文件。

### Cause

配置文件曾为类似：

```text
root:nogroup 640
```

但实际 systemd service 使用其他专用用户/组。

### Resolution

配置文件 group 必须与实际 Xray service user/group 对应，例如：

```text
root:xrayproxy 640
```

### Lesson

自动部署时不要只检查 JSON 语法，还要检查 systemd 的实际运行用户和配置文件权限。

---

## 2026-08-16 — VLESS inbound `users` 导致 UUID 不识别

### Symptom

WebSocket 已经 101，但 VLESS 仍无法正常联网；服务端日志：

```text
proxy/vless/encoding: invalid request user id: <uuid>
```

### Cause

服务端 inbound 使用了：

```text
settings.users
```

### Resolution

改为：

```text
settings.clients
```

之后连接恢复。

### Lesson

服务端 inbound 和客户端 outbound 字段不要混淆：服务端当前用 `clients`，客户端 `vnext` 仍用 `users`。

---

## 2026-08-16 — Windows BAT UTF-8 BOM 导致 CMD 第一行乱码

### Symptom

CMD 首行出现类似：

```text
锘緻echo off
```

### Cause

BAT 文件带 UTF-8 BOM。

### Resolution

生成给 Windows CMD 使用的 BAT 时保持 ASCII 兼容或至少避免 BOM。

### Lesson

Linux 端生成 BAT 时，不能只关注内容正确，还要考虑 Windows CMD 编码。

---

## 2026-08-16 — BAT 自动查找 Xray 的 PowerShell 方案曾失败

### Symptom

早期 BAT 使用 PowerShell 递归查找 `xray.exe` 时出现路径/参数解析错误。

### Resolution

改成纯 BAT 优先路径 + `for /r` 递归：

```text
bin\Xray\xray.exe
bin\xray\xray.exe
xray.exe
for /r ...
```

### Lesson

BAT 的路径发现尽量使用已经在用户 Windows 环境验证过的简单方案，不要为了“更高级”引入不必要的 PowerShell quoting 复杂度。

---

## 2026-08-16 — 候选域名实测与标签差异很大

### Observed

早期真实 VLESS 3 轮测试曾出现：

```text
vv.czcz.me       avg 1.95 MB/s
cf.877774.xyz    avg 2.60 MB/s，但波动较大
www.visa.cn      avg 2.56 MB/s，较稳定
mfa.gov.ua       avg 0.79 MB/s
```

部分其他“更多优选域名”直接失败。

随后用户继续手动测试，确认该网站“更多优选域名”整体不适合作为默认候选。

### Resolution

默认列表精简为：

- BASE
- `cf.090227.xyz`
- 主要官方站点 Cloudflare 域名

并移除静态运营商推荐。

### Lesson

“优选”“三网”等标签只能作为候选来源，最终以用户当前网络的真实 VLESS 下载为准。

---

## 2026-08-16 — 固定 IP 与域名入口速度会随时间变化

### Observed

同一个 BASE Cloudflare hostname 在不同时段的平均下载速度曾明显变化；固定 IP 也会出现失效、超时或路由变化。

### Lesson

项目长期策略应优先维护候选域名并定期实测，而不是让用户频繁手动固定/替换单个 Cloudflare IP。
