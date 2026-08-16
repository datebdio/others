# VLESS + Cloudflare 新 VPS 标准部署

目录：`network/vless-cloudflare/`

## 目标

把新 VPS 固定成一套可重复的结构：

```text
Client
  -> Cloudflare entry (Address)
  -> TLS SNI / WS Host = your business domain
  -> Cloudflare proxied hostname
  -> Nginx :443
  -> WebSocket path
  -> Xray 127.0.0.1:10000+
```

部署完成后：

1. 先用自己的业务域名作为 `Address` 验证 BASE 节点。
2. 再在 Windows 运行自动生成的 BAT。
3. BAT 仅改变 `Address`，保持 UUID / Path / Host / SNI 不变。
4. 用真实下载速度筛 PRIMARY / BACKUP。
5. 永远保留 BASE 作为故障排查与兜底。

## Cloudflare 前置准备

脚本**不调用 Cloudflare API**，只负责 VPS 内部。

运行前请先在 Cloudflare 后台完成：

1. 创建业务域名，例如 `v3.example.com`。
2. A 记录指向新 VPS IP。
3. 开启橙云代理。
4. SSL/TLS 模式使用 **Full (strict)**。
5. 创建覆盖该业务域名的 Cloudflare Origin Certificate。
6. 把证书和私钥上传到 VPS，例如：

```text
/root/origin.crt
/root/origin.key
```

Cloudflare Full (strict) 会验证回源证书；Cloudflare Origin CA 证书可用于该模式。

参考：

- Cloudflare Full (strict): https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/
- Cloudflare Origin CA: https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/

## 一键执行

当前仓库为公开仓库时，可以在新 VPS 上：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/datebdio/others/main/network/vless-cloudflare/deploy.sh)"
```

然后按提示输入：

```text
Business domain
Origin certificate path
Origin private key path
```

也可以把脚本下载后一次传入：

```bash
bash deploy.sh v3.example.com /root/origin.crt /root/origin.key
```

## 脚本会做什么

- 仅支持 Debian / Ubuntu（v1.0）
- 安装 Nginx、curl、openssl 等依赖
- 使用 XTLS 官方安装器安装/升级 Xray
- 创建独立系统用户 `xrayproxy`
- 自动生成 UUID
- 自动生成随机 WebSocket Path
- 从 `10000-10100` 自动选择空闲 Xray 内部端口
- 写入 VLESS inbound
- 配置 Nginx 443 + TLS + WebSocket 反代
- 检查证书与私钥是否匹配
- 检查 Xray 配置
- `nginx -t`
- 启动并启用 systemd 服务
- 本机 HTTPS 200 测试
- 本机 WebSocket `101 Switching Protocols` 测试
- 生成所有候选 VLESS
- 生成 Windows 自动测速 BAT
- 对已有配置做备份；失败时尽量恢复原配置

## 为什么使用 `clients` + `network: "ws"`

本模块当前固定使用：

```json
"settings": {
  "clients": [
    {
      "id": "UUID"
    }
  ],
  "decryption": "none"
},
"streamSettings": {
  "network": "ws",
  "security": "none",
  "wsSettings": {
    "path": "/random-path"
  }
}
```

原因：

- Xray-core 当前 VLESS 配置测试仍包含 `clients`。
- XTLS 官方 VLESS-WSS-Nginx 示例仍使用 `network: "ws"`。
- 这套组合已经在实际 Xray 26.3.27 服务端 + v2rayN/Xray 25.1.1 客户端上验证通过。

上游文档正在向新的配置表示方式迁移。未来升级本模块时，必须先做兼容性实测，不应仅因文档字段更新就直接替换生产配置。

参考：

- Xray-core VLESS config test: https://github.com/XTLS/Xray-core/blob/main/infra/conf/vless_test.go
- XTLS VLESS-WSS-Nginx example: https://github.com/XTLS/Xray-examples/tree/main/VLESS-WSS-Nginx
- Xray WebSocket docs: https://xtls.github.io/en/config/transports/websocket

## Nginx WebSocket

Nginx 反代 WebSocket 时会显式转发：

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

参考：

https://nginx.org/en/docs/http/websocket.html

## 部署输出

成功后 VPS 本地会生成：

```text
/root/deploy-info.txt
/root/vless-nodes.txt
/root/vless-candidate-domains.txt
/root/test-vless-domains.bat
```

### `deploy-info.txt`

保存这台服务器的部署参数和文件位置。权限为 root-only。

### `vless-nodes.txt`

包含 BASE、第三方动态优选、运营商专项和官方站点 Cloudflare 域名候选的完整 VLESS 链接及说明。

### `test-vless-domains.bat`

复制到 Windows 的 v2rayN 目录运行。

BAT 会：

- 自动寻找 `xray.exe`
- 每个候选域名启动独立临时 Xray SOCKS
- 只替换 VLESS `Address`
- 真实下载 Cloudflare Speed 测试文件
- 默认每个域名 20,000,000 bytes × 3 次
- 输出 Average / Best / Worst / Success
- 最终按平均 MB/s 排名
- 自动输出 PRIMARY / BACKUP / BASE VLESS

默认测试量较大。12 个候选 × 20 MB × 3 次理论上可超过 700 MB，请按实际流量情况调整 BAT 顶部：

```bat
set "TEST_BYTES=20000000"
set "ROUNDS=3"
```

## Address / Host / SNI 的固定规则

优选时只改：

```text
Address
```

不要改：

```text
Host = 业务域名
SNI  = 业务域名
UUID = 当前服务器 UUID
Path = 当前服务器 Path
```

例如：

```text
Address = www.visa.cn
Host    = v3.example.com
SNI     = v3.example.com
```

`Address` 决定连接哪个 Cloudflare entry；`Host/SNI` 决定 Cloudflare 最终识别哪个业务 hostname。

## 候选域名分类

候选清单在：

`candidate-domains.txt`

来源站点：

https://cf.090227.xyz/

截至 2026-08-16，该站点将候选大致分为：

### BASE

自己的 Cloudflare 橙云业务域名。

优点：

- 不依赖第三方优选 DNS
- 最适合故障排查
- 必须保留

缺点：

- Cloudflare Anycast 自动分配不一定是当前网络最快入口

### 第三方三网候选

包括：

- `cf.090227.xyz`
- `cloudflare-dl.byoip.top`
- `cf.877774.xyz`
- `saas.sin.fan`

来源站点将这些标注为三网优选候选。

优点：

- 维护方可以动态调整其 DNS 后端
- 用户不必固定记某一个 IP

缺点：

- 依赖第三方 DNS 和维护策略
- “三网优选”不等于在你的实际网络一定更快
- 必须以真实下载测试为准

### 中国移动专项

`bestcf.030101.xyz`

来源站点明确标注为中国移动专属优选。

适合：

- China Mobile 优先测试

电信/联通用户也可以测试，但不要预设它一定更优。

### 官方站点 Cloudflare 域名候选

包括：

- `www.visa.cn`
- `mfa.gov.ua`
- `www.shopify.com`
- `store.ubi.com`
- `staticdelivery.nexusmods.com`

这里的“官方站点”是指这些 hostname 属于对应组织/品牌并使用 Cloudflare。**不表示这些品牌或 Cloudflare 官方为 VLESS/代理用途提供或背书“优选服务”。**

优点：

- 不依赖个人维护的优选域名
- 某些网络下可能有较稳定的 Cloudflare entry

缺点：

- 不是针对电信/联通/移动专门设计
- DNS 和路由随时可能改变
- 某个域名今天快，不代表长期都快

## 选节点的原则

不要只看峰值。

推荐排序：

1. `Success = 3/3`
2. Average MB/s
3. Worst MB/s
4. 波动大小
5. 最后才看延迟

例如：

```text
A: 3.20 / 3.18 / 3.22 MB/s
B: 4.80 / timeout / 1.20 MB/s
```

长期主用通常优先 A。

## 安全

不要把以下实例文件提交到 GitHub：

```text
origin.key
deploy-info.txt
vless-nodes.txt
test-vless-domains.bat
```

仓库 `.gitignore` 已包含常见敏感/生成文件，但仍需人工确认提交内容。

## 更新策略

优选域名具有时效性。

未来更新时优先修改：

`candidate-domains.txt`

如果 Xray/Nginx 上游配置方式发生变化，先在测试 VPS 验证 200 / 101 / VLESS 鉴权 / 真实下载全部正常，再升级 `deploy.sh`。
