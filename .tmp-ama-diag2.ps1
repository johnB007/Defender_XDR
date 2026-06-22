$ErrorActionPreference = "SilentlyContinue"
"== all MonAgent related services =="
Get-Service | Where-Object { $_.Name -match "MonAgent|AMA|Azure Monitor" } | ForEach-Object { "SVC: $($_.Name) display=$($_.DisplayName) status=$($_.Status) start=$($_.StartType)" }
"== all MonAgent processes =="
Get-Process MonAgent*,AMAExt*,MetricsExtension* | ForEach-Object { "PROC: $($_.Name) pid=$($_.Id) start=$($_.StartTime)" }
"== handler logs in plugin folder =="
$pluginLog = "C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent\1.43.0.0\Logs"
if (Test-Path $pluginLog) {
    Get-ChildItem $pluginLog -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object { "HLOG: $($_.FullName) size=$($_.Length) mod=$($_.LastWriteTime)" }
    $hlog = Get-ChildItem $pluginLog -Recurse -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($hlog) { Get-Content $hlog.FullName -Tail 20 | ForEach-Object { "H: $_" } }
} else { "HLOG: folder absent" }
"== handler logs in WindowsAzure =="
$waLog = "C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent"
if (Test-Path $waLog) {
    Get-ChildItem $waLog -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object { "WALOG: $($_.FullName) size=$($_.Length) mod=$($_.LastWriteTime)" }
    $wlog = Get-ChildItem $waLog -Recurse -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($wlog) { Get-Content $wlog.FullName -Tail 20 | ForEach-Object { "WL: $_" } }
} else { "WALOG: folder absent" }
"== AMADataStore top-level items =="
Get-ChildItem "C:\Resources\Directory" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^AMADataStore[^.]" } | ForEach-Object {
    "DS: $($_.Name) mod=$($_.LastWriteTime)"
    Get-ChildItem $_.FullName -ErrorAction SilentlyContinue | Select-Object -First 8 | ForEach-Object { "  ITEM: $($_.Name) mod=$($_.LastWriteTime)" }
}
"== AMCS reachability =="
try { $r = Invoke-WebRequest -Uri "https://global.handler.control.monitor.azure.com/" -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop; "AMCS: $($r.StatusCode)" } catch { "AMCS: $($_.Exception.Message)" }
"== himds =="
$h = Get-Service himds -ErrorAction SilentlyContinue; "HIMDS: $($h.Status)"
