@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "EXE=%ROOT%ChatGPTProxy.exe"
set "EXT=%ROOT%extension"
set "DATA=%ROOT%data"

if /I "%~1"=="uninstall" goto UNINSTALL

echo ChatGPT Smart Proxy v0.2 installer
echo.

echo [1/6] Checking package files...
if not exist "%EXE%" (
  echo ERROR: ChatGPTProxy.exe not found.
  goto FAIL
)
if not exist "%ROOT%core\xray.exe" (
  echo ERROR: core\xray.exe not found.
  goto FAIL
)
if not exist "%EXT%\manifest.json" (
  echo ERROR: extension\manifest.json not found.
  goto FAIL
)
if not exist "%DATA%" mkdir "%DATA%"


echo [2/6] Stopping an older companion if it is running...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:17890/quit' -Method Post -ContentType 'application/json' -Body '{}' -TimeoutSec 1 | Out-Null } catch {}" >nul 2>&1
ping 127.0.0.1 -n 2 >nul
taskkill /IM ChatGPTProxy.exe /F >nul 2>&1


echo [3/6] Registering current-folder auto start...
set "CHATGPT_PROXY_EXE=%EXE%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:CHATGPT_PROXY_EXE; $k='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; New-ItemProperty -Path $k -Name 'ChatGPTProxy' -PropertyType String -Value (([char]34)+$p+([char]34)) -Force | Out-Null"
if errorlevel 1 (
  echo ERROR: Could not register auto start.
  goto FAIL
)


echo [4/6] Starting background companion...
start "" "%EXE%"


echo [5/6] Checking local API...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ok=$false; 1..30 | ForEach-Object { try { $r=Invoke-RestMethod -Uri 'http://127.0.0.1:17890/status' -TimeoutSec 1; if($r.version){$ok=$true; break} } catch {}; Start-Sleep -Milliseconds 200 }; if(-not $ok){exit 1}"
if errorlevel 1 (
  echo ERROR: Local API did not start on 127.0.0.1:17890.
  echo Check data\app.log in this folder.
  goto FAIL
)


echo [6/6] Opening the Chrome extension folder...
start "" explorer.exe "%EXT%"

echo.
echo INSTALL OK.
echo.
echo In Chrome:
echo   1. Open chrome://extensions/
echo   2. Enable Developer mode
echo   3. Click Load unpacked
echo   4. Select the extension folder that just opened
echo.
echo This program runs directly from its current folder.
echo Do not move or delete this folder after loading the extension.
echo.
pause
exit /b 0

:UNINSTALL
echo Removing auto start and stopping the companion...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "ChatGPTProxy" /f >nul 2>&1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:17890/quit' -Method Post -ContentType 'application/json' -Body '{}' -TimeoutSec 1 | Out-Null } catch {}" >nul 2>&1
echo Done. Files were not deleted.
pause
exit /b 0

:FAIL
echo.
echo INSTALL FAILED.
echo Keep this window open and check the message above.
echo.
pause
exit /b 1
