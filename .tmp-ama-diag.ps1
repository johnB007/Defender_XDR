$ErrorActionPreference = 'SilentlyContinue'
Write-Output "==== CLOCK ===="
Write-Output ("LocalTime: " + (Get-Date).ToString('o'))
Write-Output ("UTC:       " + (Get-Date).ToUniversalTime().ToString('o'))

Write-Output "==== AMA SERVICE ===="
$svc = Get-Service AzureMonitorAgent
if ($svc) { Write-Output ("AzureMonitorAgent: " + $svc.Status + " / StartType=" + $svc.StartType) } else { Write-Output "AzureMonitorAgent service NOT FOUND" }
Get-Process MonAgentCore,MonAgentHost,MonAgentManager -ErrorAction SilentlyContinue | Select-Object Name,Id,StartTime | Format-Table -Auto | Out-String | Write-Output

Write-Output "==== AMA CONFIG CACHE (DCR pulled?) ===="
$roots = @("C:\WindowsAzure\Resources","C:\ProgramData\Microsoft\AzureMonitorAgent","C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent")
foreach ($r in $roots) {
  if (Test-Path $r) {
    $cfg = Get-ChildItem -Path $r -Recurse -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "DataCollection|mcs|config" } | Select-Object -First 5
    foreach ($c in $cfg) { Write-Output ("CONFIG: " + $c.FullName + "  (" + $c.LastWriteTime.ToString('o') + ")") }
  }
}

Write-Output "==== EGRESS TESTS (443) ===="
$targets = @("global.handler.control.monitor.azure.com","eastus.handler.control.monitor.azure.com","management.azure.com","login.microsoftonline.com")
foreach ($t in $targets) {
  $r = Test-NetConnection -ComputerName $t -Port 443 -WarningAction SilentlyContinue
  Write-Output ($t + " -> TcpTestSucceeded=" + $r.TcpTestSucceeded)
}

Write-Output "==== ARC IMDS (managed identity reachable) ===="
try {
  $imds = Invoke-RestMethod -Method Get -Uri "http://localhost:40342/metadata/identity/oauth2/token?api-version=2020-06-01&resource=https://monitor.azure.com/" -Headers @{Metadata="true"} -TimeoutSec 8
  if ($imds.access_token) { Write-Output "Arc HIMDS token: OK (managed identity working)" }
} catch { Write-Output ("Arc HIMDS token: FAILED -> " + $_.Exception.Message) }

Write-Output "==== POWERSHELL LOGGING (host enablement) ===="
$sb = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -ErrorAction SilentlyContinue).EnableScriptBlockLogging
$ml = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging' -ErrorAction SilentlyContinue).EnableModuleLogging
Write-Output ("EnableScriptBlockLogging = " + ($sb)); Write-Output ("EnableModuleLogging = " + ($ml))
Write-Output "==== RECENT 4104 PRESENT LOCALLY? ===="
$evt = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational'; Id=4104; StartTime=(Get-Date).AddHours(-2)} -MaxEvents 3 -ErrorAction SilentlyContinue
if ($evt) { Write-Output ("Local 4104 events in last 2h: " + $evt.Count) } else { Write-Output "No local 4104 events in last 2h (logging likely OFF or no PS activity)" }
