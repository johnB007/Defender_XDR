$ErrorActionPreference = 'SilentlyContinue'

# Launcher / host binaries
$amaRoot = "C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent"
$ver = Get-ChildItem $amaRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
$launch = Get-ChildItem $ver.FullName -Recurse -Filter "MonAgentLauncher.exe" | Select-Object -First 1
$host1  = Get-ChildItem $ver.FullName -Recurse -Filter "MonAgentHost.exe" | Select-Object -First 1
Write-Output ("LAUNCHER: " + $launch.FullName)
Write-Output ("HOST: " + $host1.FullName)

# Current hostname vs datastores
Write-Output ("HOSTNAME: " + $env:COMPUTERNAME)
Get-ChildItem "C:\Resources\Directory" -Directory | Where-Object { $_.Name -match "AMADataStore" } | ForEach-Object { Write-Output ("DS: " + $_.Name + "  lastwrite=" + $_.LastWriteTime.ToString('o')) }

# Agent's own most-recent log across all datastores
$alog = Get-ChildItem "C:\Resources\Directory" -Recurse -Filter "*.log" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "MonAgentHost|MonAgentManager|MonAgentLauncher|maeventtable|Agent" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($alog) {
  Write-Output ("AGENTLOG: " + $alog.FullName + "  (" + $alog.LastWriteTime.ToString('o') + ")")
  Get-Content $alog.FullName -Tail 25 | ForEach-Object { Write-Output ("  " + $_) }
} else {
  Write-Output "AGENTLOG: none found"
}
