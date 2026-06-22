$ErrorActionPreference = 'SilentlyContinue'
$svc = Get-Service AzureMonitorAgent
if ($svc) { Write-Output ("AzureMonitorAgent: " + $svc.Status + " / StartType=" + $svc.StartType) } else { Write-Output "AzureMonitorAgent service STILL NOT FOUND" }
Get-Process MonAgentCore,MonAgentHost,MonAgentManager -ErrorAction SilentlyContinue | Select-Object Name,Id | Format-Table -Auto | Out-String | Write-Output
$mcs = Get-ChildItem -Path "C:\WindowsAzure\Resources" -Recurse -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "mcs|DataCollection|Configuration" } | Select-Object -First 8
if ($mcs) { foreach ($c in $mcs) { Write-Output ("DCRCFG: " + $c.FullName + "  (" + $c.LastWriteTime.ToString('o') + ")") } } else { Write-Output "No DCR config cache yet (agent may still be pulling, allow 5-10 min)" }
