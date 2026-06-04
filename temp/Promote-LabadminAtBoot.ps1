# Promote-LabadminAtBoot.ps1
# Offline-edits non-mde SYSTEM hive so the next boot runs a SYSTEM cmd
# that adds labadmin to the local Administrators group, then continues to login.
# Run on the HOST in elevated PowerShell.

param([string]$VMName = 'non-mde')

$ErrorActionPreference = 'Stop'

Write-Host "[1/6] Stopping VM..." -ForegroundColor Cyan
try { Stop-VM -Name $VMName -TurnOff -Force -ErrorAction SilentlyContinue } catch {}
Get-VMSnapshot -VMName $VMName -ErrorAction SilentlyContinue | Remove-VMSnapshot
while ((Get-VM $VMName).Status -ne 'Operating normally') { Start-Sleep 3 }

$vhd = (Get-VMHardDiskDrive -VMName $VMName).Path
try { Dismount-VHD -Path $vhd -ErrorAction SilentlyContinue } catch {}

Write-Host "[2/6] Mounting VHD..." -ForegroundColor Cyan
$disk = Mount-VHD -Path $vhd -Passthru
Start-Sleep 2
$part = $disk | Get-Disk | Get-Partition | Where-Object { $_.Type -eq 'Basic' } | Sort-Object Size -Descending | Select-Object -First 1
$letter = $null
foreach ($c in 67..90) { $cand = [char]$c; if (-not (Get-PSDrive -Name $cand -ErrorAction SilentlyContinue)) { $letter = $cand; break } }
Add-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "${letter}:\"
Start-Sleep 2
Write-Host "      mounted at ${letter}:" -ForegroundColor Green

Write-Host "[3/6] Dropping promote.cmd in Windows folder..." -ForegroundColor Cyan
$cmdPath = "${letter}:\Windows\promote.cmd"
@'
@echo off
net localgroup Administrators labadmin /add >C:\Windows\promote.log 2>&1
reg add "HKLM\SYSTEM\Setup" /v SetupType /t REG_DWORD /d 0 /f >>C:\Windows\promote.log 2>&1
reg add "HKLM\SYSTEM\Setup" /v CmdLine /t REG_SZ /d "" /f >>C:\Windows\promote.log 2>&1
exit
'@ | Set-Content -Path $cmdPath -Encoding ASCII

Write-Host "[4/6] Loading SYSTEM hive..." -ForegroundColor Cyan
& reg load HKLM\OFFSYS "${letter}:\Windows\System32\config\SYSTEM" | Out-Null

Write-Host "[5/6] Configuring Setup phase to run promote.cmd as SYSTEM at next boot..." -ForegroundColor Cyan
& reg add 'HKLM\OFFSYS\Setup' /v SetupType /t REG_DWORD /d 2 /f
& reg add 'HKLM\OFFSYS\Setup' /v CmdLine   /t REG_SZ    /d 'cmd.exe /c C:\Windows\promote.cmd' /f

Write-Host "[6/6] Unloading + dismounting + starting VM..." -ForegroundColor Cyan
[gc]::Collect(); Start-Sleep 2
& reg unload HKLM\OFFSYS | Out-Null
Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "${letter}:\" -ErrorAction SilentlyContinue
Dismount-VHD -Path $vhd
Start-VM -Name $VMName

Write-Host ""
Write-Host "Done. VM is booting. The first boot will run promote.cmd as SYSTEM," -ForegroundColor Green
Write-Host "add labadmin to Administrators, clear the Setup hook, then continue to the login screen."
Write-Host "Wait ~90s, RDP to 172.20.114.12, sign in as labadmin, then verify:"
Write-Host '   whoami /groups | findstr /i "High Mandatory"'
Write-Host '   net localgroup Administrators'
Write-Host '   type C:\Windows\promote.log'
