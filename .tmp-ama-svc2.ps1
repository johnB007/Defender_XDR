$ErrorActionPreference = "SilentlyContinue"
$ver = "C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent\1.43.0.0"
$ds  = "C:\Resources\Directory\AMADataStore.324-UM-Defcon30"
"== handler folder contents (top level) =="
Get-ChildItem $ver -ErrorAction SilentlyContinue | ForEach-Object { "VF: $($_.Name) $($_.Length)" }
"== handler status files =="
Get-ChildItem "$ver\Status" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object { "STAT: $($_.Name) mod=$($_.LastWriteTime)"; Get-Content $_.FullName -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { "  $_" } }
"== extension.log tail =="
$xl = Get-ChildItem $ver -Filter "*.log" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
foreach ($f in $xl) { "XLOG: $($f.FullName) mod=$($f.LastWriteTime)"; Get-Content $f.FullName -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { "  $_" } }
"== datastore logs =="
Get-ChildItem "$ds\logs" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 4 | ForEach-Object { "DSLOG: $($_.Name) mod=$($_.LastWriteTime)" }
$clog = Get-ChildItem "$ds\logs" -Filter "*.log" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($clog) { Get-Content $clog.FullName -Tail 15 | ForEach-Object { "DL: $_" } }
"== AMA Windows event log (last 5 errors) =="
Get-WinEvent -LogName "Microsoft-Azure-Monitor-Agent/Admin" -MaxEvents 5 -ErrorAction SilentlyContinue | ForEach-Object { "EVT: $($_.TimeCreated) [$($_.LevelDisplayName)] $($_.Message.Substring(0,[Math]::Min(200,$_.Message.Length)))" }
"== MonitoringAgent MSI installed =="
Get-Package -Name "*Azure Monitor Agent*","*AzureMonitorAgent*" -ErrorAction SilentlyContinue | ForEach-Object { "PKG: $($_.Name) $($_.Version)" }
