$ErrorActionPreference = 'SilentlyContinue'
# Pending reboot indicators
$cbs = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
$wu  = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
$pfr = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
Write-Output ("CBS RebootPending      = " + $cbs)
Write-Output ("WindowsUpdate Required = " + $wu)
Write-Output ("PendingFileRename ops  = " + (@($pfr).Count))
$lb = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Write-Output ("LastBootUpTime         = " + $lb)
# AMA extension folder present?
$amaRoot = "C:\Packages\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent"
$vers = Get-ChildItem $amaRoot -Directory -ErrorAction SilentlyContinue | Select-Object -Expand Name
Write-Output ("AMA ext versions       = " + ($vers -join ', '))
# AMA install log tail (service registration evidence)
$log = Get-ChildItem "$amaRoot" -Recurse -Filter "*.log" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Install|AMA|Setup|Enable" } | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if ($log) { Write-Output ("LOGFILE: " + $log.FullName); Get-Content $log.FullName -Tail 12 -ErrorAction SilentlyContinue | ForEach-Object { Write-Output ("  " + $_) } } else { Write-Output "No AMA install log found" }
