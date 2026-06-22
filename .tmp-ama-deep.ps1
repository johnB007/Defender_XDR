$ErrorActionPreference = 'SilentlyContinue'

# 1. Service presence via sc.exe (more reliable than Get-Service for missing svc)
$sc = & sc.exe query AzureMonitorAgent 2>&1 | Out-String
Write-Output ("SC_QUERY: " + ($sc -replace "`r?`n", " | "))

# 2. AMA package binaries
$amaRoot = "C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent"
$ver = Get-ChildItem $amaRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
Write-Output ("AMA_VER_DIR: " + $ver.FullName)
$bins = Get-ChildItem $ver.FullName -Recurse -Filter "*.exe" | Where-Object { $_.Name -match "MonAgent|AMAExt|GatewayInstall|AMAInstall" } | Select-Object -First 12
foreach ($b in $bins) { Write-Output ("BIN: " + $b.FullName) }

# 3. Extension handler status file
$statusDir = Join-Path $ver.FullName "Status"
$status = Get-ChildItem $statusDir -Filter "*.status" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($status) {
  Write-Output ("STATUS_FILE: " + $status.FullName)
  Get-Content $status.FullName -Raw | Out-String | ForEach-Object { Write-Output ("STATUS: " + ($_ -replace "`r?`n", " ")) }
}

# 4. Arc GuestConfig extension logs for AMA
$logRoot = "C:\ProgramData\GuestConfig\extension_logs\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent"
$elog = Get-ChildItem $logRoot -Recurse -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($elog) {
  Write-Output ("EXTLOG: " + $elog.FullName + "  (" + $elog.LastWriteTime.ToString('o') + ")")
  Get-Content $elog.FullName -Tail 30 | ForEach-Object { Write-Output ("  " + $_) }
} else {
  Write-Output "No GuestConfig extension log for AMA"
}

# 5. AMA's own install log under ProgramData
$amaLog = Get-ChildItem "C:\ProgramData\GuestConfig" -Recurse -Filter "*.log" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "AzureMonitorAgentInstaller|MonAgentInstall|Install" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($amaLog) {
  Write-Output ("AMA_INSTALL_LOG: " + $amaLog.FullName)
  Get-Content $amaLog.FullName -Tail 25 | ForEach-Object { Write-Output ("  " + $_) }
}
