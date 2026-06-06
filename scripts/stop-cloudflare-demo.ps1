$ErrorActionPreference = "SilentlyContinue"

$ports = 5001, 8002
foreach ($port in $ports) {
  $lines = netstat -ano | findstr ":$port"
  foreach ($line in $lines) {
    if ($line -match 'LISTENING\s+(\d+)$') {
      $procId = [int]$Matches[1]
      if ($procId -gt 0) {
        Stop-Process -Id $procId -Force
      }
    }
  }
}

Get-Process cloudflared | Stop-Process -Force

Write-Host "MoodWave demo processes stopped."
