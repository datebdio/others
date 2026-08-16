# VLESS + Cloudflare 新 VPS 标准部署

目录：`network/vless-cloudflare/`

当前版本：**v1.1.1**

## 功能

把新 VPS 固定成一套可重复的：

```text
Client
  -> Cloudflare entry (Address)
  -> TLS SNI / WS Host = 业务域名
  -> Cloudflare
  -> Nginx :443
  -> WebSocket
  -> Xray 127.0.0.1:10000+
```

部署完成后：

1. 先使用自己的业务域名作为 `Address` 验证 BASE。
2. 再把自动生成的 BAT 复制到 Windows v2rayN 目录测速。
3. BAT 只改变 `Address`，UUID / Path / Host / SNI 不变。
4. 根据真实下载速度选 PRIMARY / BACKUP。
5. 永远保留 BASE 作为故障排查与兜底。

## Cloudflare 前置准备

脚本只负责 **VPS 内部**，不调用 Cloudflare API。

运行前先完成：

1. Cloudflare 创建业务域名，例如 `v3.example.com`。
2. A 记录指向 VPS IP。
3. 开启橙云。
4. SSL/TLS 使用 **Full (strict)**。
5. 创建覆盖业务域名的 Cloudflare Origin Certificate。
6. 上传到 VPS，例如：

```text
/root/origin.crt
/root/origin.key
```

## 一键执行

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/datebdio/others/main/network/vless-cloudflare/deploy.sh)"
```

按提示输入：

```text
Business domain
Origin certificate path
Origin private key path
```

也可以：

```bash
bash deploy.sh v3.example.com /root/origin.crt /root/origin.key
```

## 脚本会做什么

- Debian / Ubuntu
- 安装 Nginx、curl、openssl 等依赖
- 使用 XTLS 官方安装器安装/升级 Xray
- 创建独立 Xray 系统用户
- 自动生成 UUID
- 自动生成随机 WebSocket Path
- 自动选择 `10000-10100` 的空闲内部端口
- 写入 VLESS + WebSocket 配置
- 配置 Nginx 443 + TLS + WebSocket 反代
- 验证证书与私钥
- Xray 配置检查
- `nginx -t`
- systemd 启动与开机启动
- 本机 HTTPS 200 测试
- 本机 WebSocket 101 测试
- 生成候选 VLESS 节点
- 生成 Windows 自动测速 BAT
- 已有配置先备份，部署失败尽量恢复

## 固定 Xray 配置

本项目使用已经实际验证过的：

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

即：

```text
VLESS inbound -> settings.clients
WebSocket     -> streamSettings.network = "ws"
```

## 部署输出

成功后生成：

```text
/root/deploy-info.txt
/root/vless-nodes.txt
/root/vless-candidate-domains.txt
/root/test-vless-domains.bat
```

### `vless-nodes.txt`

每个候选节点只保留必要说明：

```text
[节点名称]
Address  : 域名
域名介绍 : 简单介绍

vless://...
```

不再输出 Type / For / Note，也不再维护静态“推荐线路”字段。

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

当前默认 7 个候选，理论测速流量约：

```text
7 × 20 MB × 3 = 420 MB
```

可在 BAT 顶部调整：

```bat
set "TEST_BYTES=20000000"
set "ROUNDS=3"
```

## Address / Host / SNI

优选时只改：

```text
Address
```

以下保持不变：

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

## 候选域名策略

从 v1.1.0 开始，候选列表做了明显精简。

**保留：**

- 自己的 BASE 业务域名
- `cf.090227.xyz` 站点自己的三网优选域名
- 该站“官方优选域名”中的一组主要候选

**移除：**

- `cloudflare-dl.byoip.top`
- `cf.877774.xyz`
- `saas.sin.fan`
- `bestcf.030101.xyz`
- `cloudflare.182682.xyz`
- 以及“更多优选域名”中的其他第三方域名

原因：实际使用中这组“更多优选域名”表现不理想，不再作为默认候选。

### 当前候选

| 名称 | Address | 域名介绍 |
|---|---|---|
| BASE | 业务域名 | 自己的 Cloudflare 原始入口和兜底 |
| CF090227 | `cf.090227.xyz` | 优选站点自己的三网优选域名 |
| VISA | `www.visa.cn` | Visa 中国官网 Cloudflare 域名 |
| MFA | `mfa.gov.ua` | 乌克兰外交部官网 Cloudflare 域名 |
| SHOPIFY | `www.shopify.com` | Shopify 官网 Cloudflare 域名 |
| UBISOFT | `store.ubi.com` | Ubisoft 官方商店 Cloudflare 域名 |
| NEXUS | `staticdelivery.nexusmods.com` | NexusMods 静态资源 Cloudflare 域名 |

不再给候选域名预设电信 / 移动 / 联通推荐。最终以 BAT 在当前网络的真实下载结果为准。

来源站点：

https://cf.090227.xyz/

“官方站点域名”只表示这些 hostname 属于对应品牌/机构并使用 Cloudflare，不表示品牌方或 Cloudflare 为 VLESS/代理用途提供或背书服务。

## 选节点原则

长期主用建议优先：

1. `Success = 3/3`
2. Average MB/s
3. Worst MB/s
4. 波动大小
5. 延迟

例如：

```text
A: 3.20 / 3.18 / 3.22 MB/s
B: 4.80 / timeout / 1.20 MB/s
```

长期主用通常优先 A。

## 安全

不要提交：

```text
origin.key
deploy-info.txt
vless-nodes.txt
test-vless-domains.bat
```

实例 UUID、WS Path、证书私钥等只保留在目标 VPS 本地。

## 更新策略

优选域名具有时效性。

以后优先更新：

```text
candidate-domains.txt
```

如果 Xray / Nginx 上游配置发生变化，必须先在测试 VPS 验证 HTTPS 200、WebSocket 101、VLESS 鉴权和真实下载全部正常，再升级生产版本。
