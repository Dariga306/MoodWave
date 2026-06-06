param(
  [int]$BackendPort = 8002,
  [int]$FrontendPort = 5001
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $Root "moodwave-backend"
$FrontendDir = Join-Path $Root "diplom-frontend"
$RuntimeDir = Join-Path $Root "runtime\demo"
$Cloudflared = "C:\Program Files (x86)\cloudflared\cloudflared.exe"

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

function Stop-PortListener([int]$Port) {
  $lines = netstat -ano | findstr ":$Port"
  foreach ($line in $lines) {
    if ($line -match 'LISTENING\s+(\d+)$') {
      $procId = [int]$Matches[1]
      if ($procId -gt 0) {
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
      }
    }
  }
}

function Stop-CloudflaredDemo {
  Get-Process cloudflared -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $Cloudflared } |
    Stop-Process -Force -ErrorAction SilentlyContinue
}

function Wait-ForHttp([string]$Url, [int]$TimeoutSeconds = 90) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    try {
      $response = Invoke-WebRequest -UseBasicParsing $Url -TimeoutSec 5
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
        return
      }
    } catch {
      Start-Sleep -Seconds 2
    }
  } while ((Get-Date) -lt $deadline)

  throw "Timed out waiting for $Url"
}

function Test-HttpSoft([string]$Url, [int]$TimeoutSeconds = 120) {
  try {
    Wait-ForHttp $Url $TimeoutSeconds
    return $true
  } catch {
    Write-Warning $_.Exception.Message
    return $false
  }
}

function Start-Tunnel([string]$Name, [string]$TargetUrl) {
  $log = Join-Path $RuntimeDir "cloudflared-$Name.log"
  $err = Join-Path $RuntimeDir "cloudflared-$Name.err.log"
  $out = Join-Path $RuntimeDir "cloudflared-$Name.out.log"
  Remove-Item -Force $log, $err, $out -ErrorAction SilentlyContinue

  Start-Process -FilePath $Cloudflared `
    -ArgumentList @("tunnel", "--protocol", "http2", "--url", $TargetUrl, "--logfile", $log) `
    -WorkingDirectory $RuntimeDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err

  $deadline = (Get-Date).AddSeconds(45)
  do {
    foreach ($path in @($log, $err)) {
      if (Test-Path $path) {
        $match = Select-String -Path $path -Pattern "https://.*trycloudflare.com" -AllMatches |
          ForEach-Object { $_.Matches.Value } |
          Select-Object -First 1
        if ($match) {
          return $match
        }
      }
    }
    Start-Sleep -Seconds 2
  } while ((Get-Date) -lt $deadline)

  throw "Could not get Cloudflare tunnel URL for $Name. Check $log and $err"
}

function New-Qr([string]$Url) {
  $qrPath = Join-Path $RuntimeDir "moodwave-demo-qr.png"
  $python = @"
import qrcode
img = qrcode.make('$Url')
img.save(r'$qrPath')
"@
  try {
    $python | python -
    return $qrPath
  } catch {
    Write-Warning "QR package is missing. Install it with: python -m pip install qrcode[pil]"
    return ""
  }
}

if (!(Test-Path $Cloudflared)) {
  throw "cloudflared not found. Install it with: winget install --id Cloudflare.cloudflared --accept-package-agreements --accept-source-agreements"
}

Write-Host "Stopping old demo processes..."
Stop-CloudflaredDemo
Stop-PortListener $FrontendPort
Stop-PortListener $BackendPort
Start-Sleep -Seconds 2

Write-Host "Starting backend on port $BackendPort..."
$env:CORS_ORIGINS = "*"
$env:FRONTEND_URL = "*"
$backendLog = Join-Path $RuntimeDir "uvicorn-backend.log"
$backendErr = Join-Path $RuntimeDir "uvicorn-backend.err.log"
Start-Process -FilePath (Join-Path $BackendDir ".venv\Scripts\python.exe") `
  -ArgumentList @("-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "$BackendPort") `
  -WorkingDirectory $BackendDir `
  -WindowStyle Hidden `
  -RedirectStandardOutput $backendLog `
  -RedirectStandardError $backendErr

Wait-ForHttp "http://127.0.0.1:$BackendPort/health" 120

Write-Host "Opening backend tunnel..."
$backendPublicUrl = Start-Tunnel "backend" "http://127.0.0.1:$BackendPort"
Test-HttpSoft "$backendPublicUrl/health" 30 | Out-Null

Write-Host "Starting Flutter web on port $FrontendPort..."
$frontendLog = Join-Path $RuntimeDir "flutter-web.log"
$frontendErr = Join-Path $RuntimeDir "flutter-web.err.log"
Start-Process -FilePath "flutter" `
  -ArgumentList @("run", "-d", "web-server", "--web-hostname", "0.0.0.0", "--web-port=$FrontendPort", "--dart-define=API_BASE_URL=$backendPublicUrl") `
  -WorkingDirectory $FrontendDir `
  -WindowStyle Hidden `
  -RedirectStandardOutput $frontendLog `
  -RedirectStandardError $frontendErr

Wait-ForHttp "http://127.0.0.1:$FrontendPort" 180

Write-Host "Opening frontend tunnel..."
$frontendPublicUrl = Start-Tunnel "frontend" "http://127.0.0.1:$FrontendPort"
Test-HttpSoft $frontendPublicUrl 30 | Out-Null

$qrPath = New-Qr $frontendPublicUrl

@"

MoodWave demo is ready.

Frontend URL:
$frontendPublicUrl

Backend URL:
$backendPublicUrl

QR:
$qrPath

Keep this terminal session, your laptop, and internet connection alive while the committee is testing.
To stop everything later, run:
.\scripts\stop-cloudflare-demo.ps1

"@ | Tee-Object -FilePath (Join-Path $RuntimeDir "demo-links.txt")
