# Reset hvigor daemon when DevEco shows "connect error / pid does not exist".
# Usage:
# 1) Close DevEco Studio.
# 2) Run in PowerShell (no admin needed):  powershell -ExecutionPolicy Bypass -File .\\tools\\reset_hvigor_daemon.ps1

$ErrorActionPreference = 'Stop'

Write-Host "[1/3] Killing hvigor daemon node processes (if any)..."
$hvigorDaemons = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.CommandLine -like '*hvigor*daemon-process-boot-script.js*' -or $_.CommandLine -like '*daemon-process-boot-script.js*hvigor*' }

foreach ($p in $hvigorDaemons) {
  try {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
    Write-Host "  - stopped pid $($p.ProcessId)"
  } catch {
    Write-Host "  - skip pid $($p.ProcessId) ($($_.Exception.Message))"
  }
}

Write-Host "[2/3] Clearing hvigor daemon cache..."
$cacheDir = Join-Path $env:USERPROFILE ".hvigor\\daemon\\cache"
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $cacheDir "daemon-sec.json")
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $cacheDir "java-daemon.json")

Write-Host "[3/3] Done."
Write-Host "Restart DevEco Studio and rebuild the project."

