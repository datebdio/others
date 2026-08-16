#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.2.0"
CANDIDATE_URL="https://raw.githubusercontent.com/datebdio/others/main/network/vless-cloudflare/config/candidate-domains.txt"

XRAY_BIN="/usr/local/bin/xray"
XRAY_CFG="/usr/local/etc/xray/config.json"
XRAY_SERVICE="xray.service"
XRAY_USER="xrayproxy"
XRAY_GROUP="xrayproxy"

CERT_DIR="/etc/xray-cert"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

STATE_FILE="/root/deploy-info.txt"
NODES_FILE="/root/vless-nodes.txt"
BAT_FILE="/root/test-vless-domains.bat"
CANDIDATE_FILE="/root/vless-candidate-domains.txt"

BACKUP_DIR="/root/vless-deploy-backup-$(date +%Y%m%d-%H%M%S)"
SUCCESS=0

die() {
    echo
    echo "ERROR: $*" >&2
    exit 1
}

rollback() {
    local rc=$?
    if [[ "$SUCCESS" == "1" || "$rc" == "0" ]]; then
        return
    fi

    echo
    echo "============================================================"
    echo "Deployment failed. Restoring configuration backups..."
    echo "============================================================"

    set +e

    [[ -f "$BACKUP_DIR/config.json" ]] && cp -a "$BACKUP_DIR/config.json" "$XRAY_CFG"

    if [[ -n "${NGINX_SITE:-}" && -f "$BACKUP_DIR/nginx-site" ]]; then
        cp -a "$BACKUP_DIR/nginx-site" "$NGINX_SITE"
    fi

    if [[ -n "${CERT_DST:-}" && -f "$BACKUP_DIR/origin.crt" ]]; then
        cp -a "$BACKUP_DIR/origin.crt" "$CERT_DST"
    fi

    if [[ -n "${KEY_DST:-}" && -f "$BACKUP_DIR/origin.key" ]]; then
        cp -a "$BACKUP_DIR/origin.key" "$KEY_DST"
    fi

    systemctl restart "$XRAY_SERVICE" >/dev/null 2>&1 || true
    nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true

    echo "Existing configuration was restored where a backup existed."
    echo "Installed packages/binaries are intentionally left in place."
}

trap rollback EXIT

[[ "$(id -u)" -eq 0 ]] || die "Run this script as root."
[[ -r /etc/os-release ]] || die "Cannot identify operating system."

. /etc/os-release
case "${ID:-}" in
    debian|ubuntu) ;;
    *) die "Version 1.2 supports Debian/Ubuntu only. Detected: ${ID:-unknown}" ;;
esac

DOMAIN="${1:-}"
CERT_INPUT="${2:-}"
KEY_INPUT="${3:-}"

if [[ -z "$DOMAIN" ]]; then
    read -r -p "Business domain (example: v3.example.com): " DOMAIN
fi

[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || die "Invalid domain: $DOMAIN"
[[ "$DOMAIN" == *.* ]] || die "Please enter a full hostname such as v3.example.com."

if [[ -z "$CERT_INPUT" ]]; then
    read -r -p "Cloudflare Origin certificate path [/root/origin.crt]: " CERT_INPUT
    CERT_INPUT="${CERT_INPUT:-/root/origin.crt}"
fi

if [[ -z "$KEY_INPUT" ]]; then
    read -r -p "Cloudflare Origin private key path [/root/origin.key]: " KEY_INPUT
    KEY_INPUT="${KEY_INPUT:-/root/origin.key}"
fi

[[ -f "$CERT_INPUT" ]] || die "Certificate not found: $CERT_INPUT"
[[ -f "$KEY_INPUT" ]] || die "Private key not found: $KEY_INPUT"

mkdir -p "$BACKUP_DIR"

echo
echo "============================================================"
echo "VLESS + Cloudflare + Nginx deployment"
echo "Version : $SCRIPT_VERSION"
echo "Domain  : $DOMAIN"
echo "============================================================"

echo
echo "[1/12] Installing required packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends nginx curl openssl ca-certificates unzip

echo
echo "[2/12] Validating certificate and private key..."
CERT_PUB="$(
    openssl x509 -in "$CERT_INPUT" -pubkey -noout 2>/dev/null |
    openssl pkey -pubin -outform DER 2>/dev/null |
    sha256sum | awk '{print $1}'
)"
KEY_PUB="$(
    openssl pkey -in "$KEY_INPUT" -pubout -outform DER 2>/dev/null |
    sha256sum | awk '{print $1}'
)"

[[ -n "$CERT_PUB" && -n "$KEY_PUB" ]] || die "Could not read certificate/private key."
[[ "$CERT_PUB" == "$KEY_PUB" ]] || die "Certificate and private key do not match."

if openssl x509 -help 2>&1 | grep -q -- "-checkhost"; then
    openssl x509 -in "$CERT_INPUT" -noout -checkhost "$DOMAIN" >/dev/null 2>&1 || \
        die "Certificate does not match hostname $DOMAIN."
fi

echo "Certificate/key: OK"

echo
echo "[3/12] Preparing dedicated Xray service user..."
getent group "$XRAY_GROUP" >/dev/null || groupadd --system "$XRAY_GROUP"

if ! id "$XRAY_USER" >/dev/null 2>&1; then
    useradd --system \
        --gid "$XRAY_GROUP" \
        --no-create-home \
        --shell /usr/sbin/nologin \
        "$XRAY_USER"
fi

echo
echo "[4/12] Installing/upgrading Xray from the official XTLS installer..."
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
    @ install -u "$XRAY_USER"

[[ -x "$XRAY_BIN" ]] || die "Xray binary was not installed at $XRAY_BIN"

echo
echo "[5/12] Generating UUID, WebSocket path, and internal port..."
UUID="$("$XRAY_BIN" uuid)"
WSPATH="/$(openssl rand -hex 16)"

XRAY_PORT=""
for p in $(seq 10000 10100); do
    if ! ss -lntH | awk '{print $4}' | grep -Eq ":${p}$"; then
        XRAY_PORT="$p"
        break
    fi
done
[[ -n "$XRAY_PORT" ]] || die "No free internal port found in 10000-10100."

echo "UUID         : $UUID"
echo "WebSocketPath: $WSPATH"
echo "InternalPort : $XRAY_PORT"

mkdir -p "$(dirname "$XRAY_CFG")"
[[ -f "$XRAY_CFG" ]] && cp -a "$XRAY_CFG" "$BACKUP_DIR/config.json"

echo
echo "[6/12] Writing Xray configuration..."
cat > "$XRAY_CFG" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-ws",
      "listen": "127.0.0.1",
      "port": ${XRAY_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "email": "vless-cloudflare"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "${WSPATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

chown root:"$XRAY_GROUP" "$XRAY_CFG"
chmod 640 "$XRAY_CFG"
"$XRAY_BIN" run -test -c "$XRAY_CFG"

echo
echo "[7/12] Installing Cloudflare Origin certificate for Nginx..."
mkdir -p "$CERT_DIR"
CERT_DST="$CERT_DIR/${DOMAIN}.crt"
KEY_DST="$CERT_DIR/${DOMAIN}.key"

[[ -f "$CERT_DST" ]] && cp -a "$CERT_DST" "$BACKUP_DIR/origin.crt"
[[ -f "$KEY_DST" ]] && cp -a "$KEY_DST" "$BACKUP_DIR/origin.key"

install -m 644 "$CERT_INPUT" "$CERT_DST"
install -m 600 "$KEY_INPUT" "$KEY_DST"

echo
echo "[8/12] Writing Nginx configuration..."
mkdir -p "$NGINX_AVAILABLE" "$NGINX_ENABLED"
NGINX_SITE="$NGINX_AVAILABLE/$DOMAIN"
[[ -f "$NGINX_SITE" ]] && cp -a "$NGINX_SITE" "$BACKUP_DIR/nginx-site"

cat > "$NGINX_SITE" <<EOF
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ${DOMAIN};

    ssl_certificate ${CERT_DST};
    ssl_certificate_key ${KEY_DST};
    ssl_protocols TLSv1.2 TLSv1.3;

    location = ${WSPATH} {
        proxy_pass http://127.0.0.1:${XRAY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    location / {
        default_type text/plain;
        return 200 "${DOMAIN} OK\n";
    }
}
EOF

ln -sfn "$NGINX_SITE" "$NGINX_ENABLED/$DOMAIN"
nginx -t

echo
echo "[9/12] Starting Xray and reloading Nginx..."
systemctl daemon-reload
systemctl enable "$XRAY_SERVICE" >/dev/null
systemctl restart "$XRAY_SERVICE"
systemctl enable nginx >/dev/null
systemctl restart nginx
sleep 2

systemctl is-active --quiet "$XRAY_SERVICE" || die "xray.service is not active."
systemctl is-active --quiet nginx || die "nginx is not active."
ss -lntH | awk '{print $4}' | grep -Eq ":${XRAY_PORT}$" || \
    die "Xray is not listening on internal port $XRAY_PORT."

echo
echo "[10/12] Running local HTTPS and WebSocket tests..."
HTTP_CODE="$(
    curl -sk \
      --resolve "${DOMAIN}:443:127.0.0.1" \
      --connect-timeout 5 \
      --max-time 10 \
      -o /dev/null \
      -w '%{http_code}' \
      "https://${DOMAIN}/" || true
)"
[[ "$HTTP_CODE" == "200" ]] || die "Local HTTPS test failed. HTTP=$HTTP_CODE"

WS_HEADERS="$(
    curl -sk --http1.1 \
      --resolve "${DOMAIN}:443:127.0.0.1" \
      --connect-timeout 5 \
      --max-time 4 \
      -D - -o /dev/null \
      -H "Connection: Upgrade" \
      -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
      "https://${DOMAIN}${WSPATH}" 2>/dev/null || true
)"

grep -qiE '^HTTP/[0-9.]+ 101 ' <<<"$WS_HEADERS" || {
    echo "$WS_HEADERS"
    die "Local WebSocket handshake did not return HTTP 101."
}

echo "HTTPS test    : 200 OK"
echo "WebSocket test: 101 Switching Protocols"

echo
echo "[11/12] Loading candidate Cloudflare entry domains..."
if ! curl -fsSL "$CANDIDATE_URL" -o "$CANDIDATE_FILE"; then
    echo "Warning: Could not download candidate list. Using embedded fallback list."
    cat > "$CANDIDATE_FILE" <<'CANDIDATES'
# NAME|ADDRESS|INTRO
BASE|__BASE__|自己的 Cloudflare 业务域名，作为原始入口和故障兜底。
CF090227|cf.090227.xyz|cf.090227.xyz 站点自己的三网优选域名。
VISA|www.visa.cn|Visa 中国官网 Cloudflare 域名，必须使用带 www 的地址。
MFA|mfa.gov.ua|乌克兰外交部官网 Cloudflare 域名。
SHOPIFY|www.shopify.com|Shopify 官网 Cloudflare 域名。
UBISOFT|store.ubi.com|Ubisoft 官方商店 Cloudflare 域名。
NEXUS|staticdelivery.nexusmods.com|NexusMods 静态资源 Cloudflare 域名。
CANDIDATES
fi

ENC_PATH="%2F${WSPATH#/}"

cat > "$NODES_FILE" <<EOF
============================================================
VLESS + Cloudflare deployment result
============================================================

Business domain : ${DOMAIN}
Port            : 443
UUID            : ${UUID}
Transport       : WebSocket
Path            : ${WSPATH}
Host            : ${DOMAIN}
SNI             : ${DOMAIN}
TLS             : ON
ALPN            : http/1.1
Xray internal   : 127.0.0.1:${XRAY_PORT}

Rule: only Address changes. Host/SNI always remain ${DOMAIN}.
Keep BASE as fallback.

============================================================
NODES
============================================================
EOF

while IFS='|' read -r NAME ADDRESS INTRO; do
    [[ -z "$NAME" || "$NAME" == \#* ]] && continue
    [[ "$ADDRESS" == "__BASE__" ]] && ADDRESS="$DOMAIN"

    {
        echo
        echo "------------------------------------------------------------"
        echo "[$NAME]"
        echo "Address  : $ADDRESS"
        echo "域名介绍 : $INTRO"
        echo
        echo "vless://${UUID}@${ADDRESS}:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ENC_PATH}&alpn=http%2F1.1#${DOMAIN}-${NAME}"
    } >> "$NODES_FILE"
done < "$CANDIDATE_FILE"

echo
echo "[12/12] Generating Windows domain speed-test BAT..."

cat > "$BAT_FILE" <<EOF
@echo off
setlocal EnableExtensions EnableDelayedExpansion
title VLESS Domain Download Speed Test - ${DOMAIN}

REM Auto-generated by deploy.sh v${SCRIPT_VERSION}
REM Only Address changes. UUID / Path / Host / SNI stay fixed.

set "UUID=${UUID}"
set "HOST=${DOMAIN}"
set "SNI=${DOMAIN}"
set "WSPATH=${WSPATH}"
set "PORT=443"
set "SOCKS_PORT=10999"
set "TEST_BYTES=20000000"
set "ROUNDS=3"
set "CONNECT_TIMEOUT=20"
set "MAX_TIME=120"

set "BASE=%~dp0"
set "XRAY="
set "CFG=%TEMP%\cf_domain_test_xray.json"
set "PIDFILE=%TEMP%\cf_domain_test_xray.pid"
set "CURL_OUT=%TEMP%\cf_domain_test_curl.txt"
set "CURL_ERR=%TEMP%\cf_domain_test_curl.err"
set "XRAY_OUT=%TEMP%\cf_domain_test_xray_out.log"
set "XRAY_ERR=%TEMP%\cf_domain_test_xray_err.log"
set "RESULT=%BASE%domain_speed_results.csv"
set "RECOMMENDED=%BASE%recommended_vless.txt"

echo.
echo ============================================================
echo VLESS Cloudflare Domain Speed Test
echo ============================================================
echo Server        : %HOST%
echo Test size     : 20,000,000 bytes
echo Rounds/domain : %ROUNDS%
echo ============================================================
echo.

if exist "%BASE%bin\Xray\xray.exe" set "XRAY=%BASE%bin\Xray\xray.exe"
if not defined XRAY if exist "%BASE%bin\xray\xray.exe" set "XRAY=%BASE%bin\xray\xray.exe"
if not defined XRAY if exist "%BASE%xray.exe" set "XRAY=%BASE%xray.exe"
if not defined XRAY (
    for /r "%BASE%" %%I in (xray.exe) do (
        if not defined XRAY if exist "%%~fI" set "XRAY=%%~fI"
    )
)

if not defined XRAY (
    echo ERROR: xray.exe was not found under:
    echo %BASE%
    echo Put this BAT inside your v2rayN folder.
    pause
    exit /b 1
)

echo Xray: %XRAY%
echo.

netstat -ano | findstr /R /C:":%SOCKS_PORT% .*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo ERROR: Port %SOCKS_PORT% is already in use.
    pause
    exit /b 1
)

> "%RESULT%" echo Name,Domain,SuccessfulRuns,AverageMBps,BestMBps,WorstMBps,Status

EOF

while IFS='|' read -r NAME ADDRESS INTRO; do
    [[ -z "$NAME" || "$NAME" == \#* ]] && continue
    [[ "$ADDRESS" == "__BASE__" ]] && ADDRESS="$DOMAIN"
    printf 'call :TEST "%s" "%s"\r\n' "$NAME" "$ADDRESS" >> "$BAT_FILE"
done < "$CANDIDATE_FILE"

cat >> "$BAT_FILE" <<'EOF'

goto :FINAL

:TEST
set "NAME=%~1"
set "DOMAIN=%~2"
set "GOOD=0"
set "SUM=0"
set "BEST=0"
set "WORST=2147483647"
set "XPID="
set "READY=0"

echo.
echo ============================================================
echo [%NAME%]
echo Address: %DOMAIN%
echo ============================================================

> "%CFG%" (
    echo {
    echo   "log": {"loglevel": "warning"},
    echo   "inbounds": [
    echo     {
    echo       "listen": "127.0.0.1",
    echo       "port": %SOCKS_PORT%,
    echo       "protocol": "socks",
    echo       "settings": {"udp": true}
    echo     }
    echo   ],
    echo   "outbounds": [
    echo     {
    echo       "tag": "proxy",
    echo       "protocol": "vless",
    echo       "settings": {
    echo         "vnext": [
    echo           {
    echo             "address": "%DOMAIN%",
    echo             "port": %PORT%,
    echo             "users": [
    echo               {
    echo                 "id": "%UUID%",
    echo                 "encryption": "none"
    echo               }
    echo             ]
    echo           }
    echo         ]
    echo       },
    echo       "streamSettings": {
    echo         "network": "ws",
    echo         "security": "tls",
    echo         "tlsSettings": {
    echo           "serverName": "%SNI%",
    echo           "alpn": ["http/1.1"],
    echo           "allowInsecure": false
    echo         },
    echo         "wsSettings": {
    echo           "path": "%WSPATH%",
    echo           "headers": {"Host": "%HOST%"}
    echo         }
    echo       }
    echo     }
    echo   ]
    echo }
)

"%XRAY%" run -test -c "%CFG%" >nul 2>&1
if errorlevel 1 (
    echo Xray config test: FAILED
    >> "%RESULT%" echo %NAME%,%DOMAIN%,0,0,0,0,CONFIG_FAILED
    exit /b 0
)

set "XRAY_ENV=%XRAY%"
set "CFG_ENV=%CFG%"
set "PIDFILE_ENV=%PIDFILE%"
set "XRAY_OUT_ENV=%XRAY_OUT%"
set "XRAY_ERR_ENV=%XRAY_ERR%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Start-Process -FilePath $env:XRAY_ENV -ArgumentList @('run','-c',$env:CFG_ENV) -WindowStyle Hidden -RedirectStandardOutput $env:XRAY_OUT_ENV -RedirectStandardError $env:XRAY_ERR_ENV -PassThru; Set-Content -Encoding ASCII -Path $env:PIDFILE_ENV -Value $p.Id" >nul 2>&1

if exist "%PIDFILE%" set /p XPID=<"%PIDFILE%"

for /L %%W in (1,1,8) do (
    if "!READY!"=="0" (
        netstat -ano | findstr /R /C:":%SOCKS_PORT% .*LISTENING" >nul 2>&1
        if not errorlevel 1 (
            set "READY=1"
        ) else (
            timeout /t 1 /nobreak >nul
        )
    )
)

if "!READY!"=="0" (
    echo Temporary Xray start: FAILED
    if exist "%XRAY_ERR%" type "%XRAY_ERR%"
    >> "%RESULT%" echo %NAME%,%DOMAIN%,0,0,0,0,XRAY_START_FAILED
    goto :TEST_CLEANUP
)

curl.exe --proxy socks5h://127.0.0.1:%SOCKS_PORT% ^
  --connect-timeout 10 --max-time 20 ^
  -o NUL -sS -w "%%{http_code}" ^
  "https://speed.cloudflare.com/__down?bytes=10000&r=!RANDOM!" ^
  > "%CURL_OUT%" 2> "%CURL_ERR%"

set "PRE_RC=!ERRORLEVEL!"
set "PRE_HTTP="
if exist "%CURL_OUT%" set /p PRE_HTTP=<"%CURL_OUT%"

if not "!PRE_RC!"=="0" (
    echo Precheck: FAILED  CurlExit=!PRE_RC!
    if exist "%CURL_ERR%" type "%CURL_ERR%"
    >> "%RESULT%" echo %NAME%,%DOMAIN%,0,0,0,0,FAILED
    goto :TEST_CLEANUP
)

if not "!PRE_HTTP!"=="200" (
    echo Precheck: FAILED  HTTP=!PRE_HTTP!
    >> "%RESULT%" echo %NAME%,%DOMAIN%,0,0,0,0,FAILED
    goto :TEST_CLEANUP
)

echo Precheck: OK
echo.

for /L %%R in (1,1,%ROUNDS%) do (
    type nul > "%CURL_OUT%"
    type nul > "%CURL_ERR%"

    curl.exe --proxy socks5h://127.0.0.1:%SOCKS_PORT% ^
      --connect-timeout %CONNECT_TIMEOUT% ^
      --max-time %MAX_TIME% ^
      -L -o NUL -sS ^
      -w "%%{http_code}|%%{size_download}|%%{speed_download}|%%{time_total}" ^
      "https://speed.cloudflare.com/__down?bytes=%TEST_BYTES%&r=!RANDOM!!RANDOM!" ^
      > "%CURL_OUT%" 2> "%CURL_ERR%"

    set "RC=!ERRORLEVEL!"
    set "LINE="
    set "HTTP="
    set "SIZE="
    set "SPEED="
    set "TOTAL="

    if exist "%CURL_OUT%" set /p LINE=<"%CURL_OUT%"

    for /f "tokens=1-4 delims=|" %%A in ("!LINE!") do (
        set "HTTP=%%A"
        set "SIZE=%%B"
        set "SPEED=%%C"
        set "TOTAL=%%D"
    )

    if "!RC!"=="0" if "!HTTP!"=="200" if defined SPEED (
        set /a GOOD+=1
        set /a SUM+=SPEED
        if !SPEED! GTR !BEST! set "BEST=!SPEED!"
        if !SPEED! LSS !WORST! set "WORST=!SPEED!"

        for /f "delims=" %%M in ('powershell -NoProfile -Command "([math]::Round(([double]!SPEED!)/1MB,2)).ToString([Globalization.CultureInfo]::InvariantCulture)"') do set "MBPS=%%M"
        echo Run %%R: !MBPS! MB/s   Time=!TOTAL!s
    ) else (
        echo Run %%R: FAILED   CurlExit=!RC! HTTP=!HTTP! Downloaded=!SIZE!
        if exist "%CURL_ERR%" type "%CURL_ERR%"
    )
)

if !GOOD! GTR 0 (
    set /a AVG_BPS=SUM/GOOD

    for /f "delims=" %%M in ('powershell -NoProfile -Command "([math]::Round(([double]!AVG_BPS!)/1MB,2)).ToString([Globalization.CultureInfo]::InvariantCulture)"') do set "AVG_MB=%%M"
    for /f "delims=" %%M in ('powershell -NoProfile -Command "([math]::Round(([double]!BEST!)/1MB,2)).ToString([Globalization.CultureInfo]::InvariantCulture)"') do set "BEST_MB=%%M"
    for /f "delims=" %%M in ('powershell -NoProfile -Command "([math]::Round(([double]!WORST!)/1MB,2)).ToString([Globalization.CultureInfo]::InvariantCulture)"') do set "WORST_MB=%%M"

    if !GOOD! EQU %ROUNDS% (
        set "STATUS=OK"
    ) else (
        set "STATUS=PARTIAL"
    )

    echo.
    echo Average: !AVG_MB! MB/s
    echo Best   : !BEST_MB! MB/s
    echo Worst  : !WORST_MB! MB/s
    echo Success: !GOOD!/%ROUNDS%

    >> "%RESULT%" echo %NAME%,%DOMAIN%,!GOOD!,!AVG_MB!,!BEST_MB!,!WORST_MB!,!STATUS!
) else (
    echo.
    echo Average: FAILED
    echo Success: 0/%ROUNDS%
    >> "%RESULT%" echo %NAME%,%DOMAIN%,0,0,0,0,FAILED
)

:TEST_CLEANUP
if defined XPID taskkill /PID !XPID! /T /F >nul 2>&1
del /q "%PIDFILE%" >nul 2>&1
exit /b 0

:FINAL
del /q "%CFG%" "%PIDFILE%" "%CURL_OUT%" "%CURL_ERR%" "%XRAY_OUT%" "%XRAY_ERR%" >nul 2>&1

echo.
echo ============================================================
echo FINAL RANKING
echo ============================================================

set "RESULT_ENV=%RESULT%"
set "RECOMMENDED_ENV=%RECOMMENDED%"
set "UUID_ENV=%UUID%"
set "HOST_ENV=%HOST%"
set "WSPATH_ENV=%WSPATH%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$r=Import-Csv $env:RESULT_ENV; $ok=$r | Where-Object {$_.Status -eq 'OK'} | Sort-Object @{Expression={[double]$_.AverageMBps};Descending=$true}; $ok | Format-Table Name,Domain,SuccessfulRuns,AverageMBps,BestMBps,WorstMBps,Status -AutoSize; $enc=[uri]::EscapeDataString($env:WSPATH_ENV); $lines=@(); $top=@($ok | Select-Object -First 2); if($top.Count -ge 1){$a=$top[0].Domain; $lines += '[PRIMARY]'; $lines += ('vless://'+$env:UUID_ENV+'@'+$a+':443?encryption=none&security=tls&sni='+$env:HOST_ENV+'&type=ws&host='+$env:HOST_ENV+'&path='+$enc+'&alpn=http%2F1.1#PRIMARY-'+$a); $lines += ''}; if($top.Count -ge 2){$a=$top[1].Domain; $lines += '[BACKUP]'; $lines += ('vless://'+$env:UUID_ENV+'@'+$a+':443?encryption=none&security=tls&sni='+$env:HOST_ENV+'&type=ws&host='+$env:HOST_ENV+'&path='+$enc+'&alpn=http%2F1.1#BACKUP-'+$a); $lines += ''}; $lines += '[BASE-FALLBACK]'; $lines += ('vless://'+$env:UUID_ENV+'@'+$env:HOST_ENV+':443?encryption=none&security=tls&sni='+$env:HOST_ENV+'&type=ws&host='+$env:HOST_ENV+'&path='+$enc+'&alpn=http%2F1.1#BASE-'+$env:HOST_ENV); $lines | Set-Content -Encoding UTF8 $env:RECOMMENDED_ENV; Write-Host ''; Write-Host 'Recommended VLESS nodes:'; $lines | ForEach-Object {Write-Host $_}"

echo.
echo Results:
echo %RESULT%
echo Recommended nodes:
echo %RECOMMENDED%
echo.
pause
EOF

chmod 644 "$BAT_FILE" "$CANDIDATE_FILE"

cat > "$STATE_FILE" <<EOF
VLESS Cloudflare deployment
Version=${SCRIPT_VERSION}
Installed=$(date -Is)
Domain=${DOMAIN}
UUID=${UUID}
Path=${WSPATH}
XrayPort=${XRAY_PORT}
XrayConfig=${XRAY_CFG}
NginxConfig=${NGINX_SITE}
Certificate=${CERT_DST}
PrivateKey=${KEY_DST}
CandidateList=${CANDIDATE_FILE}
Nodes=${NODES_FILE}
WindowsBAT=${BAT_FILE}
BackupDir=${BACKUP_DIR}
EOF
chmod 600 "$STATE_FILE" "$NODES_FILE"

SUCCESS=1

echo
echo "============================================================"
echo "DEPLOYMENT SUCCESSFUL"
echo "============================================================"
echo "Domain          : $DOMAIN"
echo "UUID            : $UUID"
echo "WebSocket Path  : $WSPATH"
echo "Xray internal   : 127.0.0.1:$XRAY_PORT"
echo
echo "Generated files:"
echo "  $STATE_FILE"
echo "  $NODES_FILE"
echo "  $CANDIDATE_FILE"
echo "  $BAT_FILE"
echo
echo "Next:"
echo "1. Confirm Cloudflare DNS is proxied (orange cloud)."
echo "2. Confirm SSL/TLS mode is Full (strict)."
echo "3. Import BASE first and verify connectivity."
echo "4. Copy test-vless-domains.bat into the v2rayN folder and run it."
echo "============================================================"
