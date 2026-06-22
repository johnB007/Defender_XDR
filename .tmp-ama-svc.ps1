$ErrorActionPreference = "SilentlyContinue"
"== AMA processes =="
Get-Process MonAgent*,MetricsExtension*,AMAExt* | Select-Object Name,Id,StartTime | ForEach-Object { "PROC: $($_.Name) pid=$($_.Id) start=$($_.StartTime)" }
"== services matching mon/azure/ama =="
Get-Service | Where-Object { $_.Name -match "Mon|Azure|AMA|GCArc|himds|Extension" } | ForEach-Object { "SVC: $($_.Name) = $($_.Status)" }
"== package version folder =="
$pkg = "C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent"
Get-ChildItem $pkg -Directory | ForEach-Object { "PKGVER: $($_.Name)" }
"== launcher/core exe present =="
Get-ChildItem $pkg -Recurse -Include MonAgentLauncher.exe,MonAgentCore.exe,MonAgentHost.exe -ErrorAction SilentlyContinue | Select-Object -First 5 | ForEach-Object { "BIN: $($_.FullName)" }
"== active data store =="
Get-ChildItem "C:\Resources\Directory" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^AMADataStore" } | ForEach-Object { "DS: $($_.Name) mod=$($_.LastWriteTime)" }
"== tail MonAgentHost.log =="
$log = Get-ChildItem $pkg -Recurse -Filter MonAgentHost.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) { "LOGFILE: $($log.FullName) mod=$($log.LastWriteTime)"; Get-Content $log.FullName -Tail 15 | ForEach-Object { "LOG: $_" } } else { "LOGFILE: none found" }
