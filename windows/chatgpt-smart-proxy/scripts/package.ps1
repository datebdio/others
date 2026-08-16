param(
  [string]$Version = "0.2.0",
  [string]$XrayVersion = "26.3.27"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $ProjectRoot "../..")
$Work = Join-Path $env:TEMP "chatgpt-smart-proxy-build"
$StageName = "ChatGPT-Smart-Proxy-v$Version"
$Stage = Join-Path $Work $StageName
$ReleaseDir = Join-Path $ProjectRoot "releases"
$ZipPath = Join-Path $ReleaseDir "$StageName-Windows-x64.zip"

Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Stage, (Join-Path $Stage "core"), (Join-Path $Stage "extension"), (Join-Path $Stage "licenses"), (Join-Path $Stage "data"), $ReleaseDir | Out-Null

Push-Location (Join-Path $ProjectRoot "src/companion")
try {
  $env:GOOS = "windows"
  $env:GOARCH = "amd64"
  $env:CGO_ENABLED = "0"
  go test ./...
  go build -trimpath -ldflags "-s -w -H=windowsgui" -o (Join-Path $Stage "ChatGPTProxy.exe") .
} finally {
  Pop-Location
  Remove-Item Env:GOOS -ErrorAction SilentlyContinue
  Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
  Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue
}

Copy-Item (Join-Path $ProjectRoot "extension/*") (Join-Path $Stage "extension") -Recurse -Force
Copy-Item (Join-Path $ProjectRoot "install.cmd") $Stage -Force
Copy-Item (Join-Path $ProjectRoot "使用说明.txt") $Stage -Force
$LicenseSource = Join-Path $ProjectRoot "licenses/Xray-LICENSE.txt"
if (Test-Path $LicenseSource) {
  Copy-Item $LicenseSource (Join-Path $Stage "licenses/Xray-LICENSE.txt") -Force
} else {
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/XTLS/Xray-core/v$XrayVersion/LICENSE" -OutFile (Join-Path $Stage "licenses/Xray-LICENSE.txt")
}

$XrayZip = Join-Path $Work "xray.zip"
$XrayUrl = "https://github.com/XTLS/Xray-core/releases/download/v$XrayVersion/Xray-windows-64.zip"
Invoke-WebRequest -Uri $XrayUrl -OutFile $XrayZip

if ($XrayVersion -eq "26.3.27") {
  $Expected = "d004c39288ce9ada487c6f398c7c545f7d749e44bdfdd59dbc9f865afba4e1ad"
  $Actual = (Get-FileHash -Algorithm SHA256 $XrayZip).Hash.ToLowerInvariant()
  if ($Actual -ne $Expected) { throw "Xray SHA256 mismatch: $Actual" }
}

$XrayExtract = Join-Path $Work "xray"
Expand-Archive -Path $XrayZip -DestinationPath $XrayExtract -Force
Copy-Item (Join-Path $XrayExtract "xray.exe") (Join-Path $Stage "core/xray.exe") -Force
Copy-Item (Join-Path $XrayExtract "geoip.dat") (Join-Path $Stage "core/geoip.dat") -Force
Copy-Item (Join-Path $XrayExtract "geosite.dat") (Join-Path $Stage "core/geosite.dat") -Force

Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path $Stage -DestinationPath $ZipPath -CompressionLevel Optimal
$Hash = (Get-FileHash -Algorithm SHA256 $ZipPath).Hash.ToLowerInvariant()
"$Hash  $(Split-Path -Leaf $ZipPath)" | Set-Content -Path (Join-Path $ReleaseDir "SHA256SUMS.txt") -Encoding ascii
Write-Host "Built: $ZipPath"
Write-Host "SHA256: $Hash"
