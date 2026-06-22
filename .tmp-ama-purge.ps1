$ErrorActionPreference = 'SilentlyContinue'

# Stop any lingering AMA processes so files are unlocked
$names = 'MonAgentCore','MonAgentHost','MonAgentManager','MonAgentLauncher','MetricsExtension.Native','AMAExtHealthMonitor','MonAgentClient'
foreach ($n in $names) {
  Get-Process $n -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction Stop; Write-Output ("STOPPED: " + $n + " (" + $_.Id + ")") } catch { Write-Output ("STOP-FAIL: " + $n + " " + $_.Exception.Message) }
  }
}
Start-Sleep -Seconds 3

# Purge stale data stores (rename out of the way rather than hard delete, safest)
$base = "C:\Resources\Directory"
$stamp = (Get-Date).ToString('yyyyMMddHHmmss')
Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^AMADataStore' } | ForEach-Object {
  $dst = $_.FullName + ".old_" + $stamp
  try { Rename-Item -Path $_.FullName -NewName $dst -ErrorAction Stop; Write-Output ("PURGED: " + $_.Name + " -> " + (Split-Path $dst -Leaf)) }
  catch { Write-Output ("PURGE-FAIL: " + $_.Name + " " + $_.Exception.Message) }
}

# Confirm clean
$left = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^AMADataStore' -and $_.Name -notmatch '\.old_' }
if ($left) { foreach ($l in $left) { Write-Output ("REMAINING-ACTIVE: " + $l.Name) } } else { Write-Output "REMAINING-ACTIVE: none (clean)" }
