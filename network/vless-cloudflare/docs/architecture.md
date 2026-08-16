# Architecture

## Base path

```text
Windows / v2rayN
    |
    | Address = business.example.com
    | SNI     = business.example.com
    | WS Host = business.example.com
    v
Cloudflare Edge
    |
    | HTTPS origin connection
    | Full (strict)
    v
Nginx :443 on VPS
    |
    | exact WebSocket path
    v
Xray 127.0.0.1:10000+
    |
    v
Internet
```

## Optimized-domain path

```text
Windows / v2rayN
    |
    | Address = candidate-domain.example
    | SNI     = business.example.com
    | WS Host = business.example.com
    v
Cloudflare entry selected by candidate domain
    |
    | Cloudflare still sees the business hostname
    v
business.example.com zone/origin
    |
    v
Nginx :443
    |
    v
Xray
```

The candidate domain is used as the **dial address**.

The business hostname remains the **TLS/HTTP identity**.

## Why BASE must remain

If an optimized domain fails, BASE helps determine whether the problem is:

- candidate DNS
- Cloudflare entry/routing
- the business zone
- Nginx
- Xray
- VLESS authentication

If BASE also fails, do not keep changing candidate domains. Diagnose the server path first.

## Server split

Nginx terminates TLS because Cloudflare Origin CA is installed there.

Xray listens only on loopback:

```text
127.0.0.1:10000+
```

This avoids exposing the internal VLESS listener directly to the Internet.

## Validation sequence

A successful deployment must pass all of these:

```text
Xray config test
-> nginx -t
-> xray.service active
-> nginx active
-> internal Xray port listening
-> local HTTPS returns 200
-> local WebSocket returns 101
-> BASE VLESS can browse
-> candidate-domain BAT can perform real downloads
```

Do not treat `ping` or TCP connect alone as proof that a VLESS route works.
