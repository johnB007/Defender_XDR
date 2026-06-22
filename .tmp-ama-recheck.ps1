$ErrorActionPreference = 'SilentlyContinue'

# Service (exact)
$q = & sc.exe query AzureMonitorAgent 2>&1 | Out-String
Write-Output ("SC: " + ($q -replace "`r?`n", " | ").Trim())

# Core telemetry processes
$procs = Get-Process MonAgentCore,MonAgentHost,MonAgentManager,MonAgentLauncher,MetricsExtension.Native -ErrorAction SilentlyContinue | Select-Object Name,Id
if ($procs) { foreach ($p in $procs) { Write-Output ("PROC: " + $p.Name + " (" + $p.Id + ")") } } else { Write-Output "PROC: none of the MonAgent processes are running" }

# DCR config cache, search both Azure VM and Arc locations
$cfg = Get-ChildItem -Path "C:\" -Recurse -Filter "mcsconfig*.json" -ErrorAction SilentlyContinue | Select-Object -First 5
if (-not $cfg) { $cfg = Get-ChildItem -Path "C:\" -Recurse -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "AMADataStore\\mcs|DataCollectionRules|configchunks" } | Select-Object -First 5 }
if ($cfg) { foreach ($c in $cfg) { Write-Output ("DCRCFG: " + $c.FullName + "  (" + $c.LastWriteTime.ToString('o') + ")") } } else { Write-Output "DCRCFG: still none" }

# AMADataStore location (whichever exists)
foreach ($p in @("C:\WindowsAzure\Resources","C:\Resources\Directory","C:\Resources")) {
  $d = Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "AMADataStore" }
  if ($d) { Write-Output ("DATASTORE: " + $d.FullName) }
}
