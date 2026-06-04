# Harden-NonMdeVm.ps1
# Offline-edits the non-mde VM disk to:
#   - disable UAC (so labadmin gets a full admin token)
#   - turn off Tamper Protection
#   - enable Network Protection (Block mode)
#   - enable SmartScreen for Explorer + Edge policy
# Run on the HOST in an elevated PowerShell window.

param(
  [string]$VMName = 'non-mde'
)

$ErrorActionPreference = 'Stop'

Write-Host "[1/7] Stopping VM and removing snapshots..." -ForegroundColor Cyan
try { Stop-VM -Name $VMName -TurnOff -Force -ErrorAction SilentlyContinue } catch {}
Get-VMSnapshot -VMName $VMName | Remove-VMSnapshot
while ((Get-VM $VMName).Status -ne 'Operating normally') { Start-Sleep 3 }

$vhd = (Get-VMHardDiskDrive -VMName $VMName).Path
Write-Host "[2/7] VHD: $vhd"
if (-not (Test-Path $vhd)) { throw "VHD not found: $vhd" }

Write-Host "[3/7] Mounting VHD and assigning drive letter to Windows partition..." -ForegroundColor Cyan
$disk = Mount-VHD -Path $vhd -Passthru
Start-Sleep 2
$part = $disk | Get-Disk | Get-Partition | Where-Object { $_.Type -eq 'Basic' } | Sort-Object Size -Descending | Select-Object -First 1
if (-not $part) { throw "No Basic partition found" }

$letter = $null
foreach ($c in 67..90) { # C..Z
  $candidate = [char]$c
  if (-not (Get-PSDrive -Name $candidate -ErrorAction SilentlyContinue)) { $letter = $candidate; break }
}
if (-not $letter) { throw "No free drive letter" }

Add-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "${letter}:\"
Start-Sleep 2
$drv = $letter
if (-not (Test-Path "${drv}:\Windows\System32\config\SOFTWARE")) { throw "SOFTWARE hive not found on ${drv}:" }
Write-Host "      Windows partition mounted at ${drv}:" -ForegroundColor Green

Write-Host "[4/7] Loading offline SOFTWARE hive..." -ForegroundColor Cyan
& reg load HKLM\OFFSW "${drv}:\Windows\System32\config\SOFTWARE" | Out-Null

Write-Host "[5/7] Writing registry values..." -ForegroundColor Cyan
$pol = 'HKLM\OFFSW\Microsoft\Windows\CurrentVersion\Policies\System'
& reg add $pol /v EnableLUA                       /t REG_DWORD /d 0 /f | Out-Null
& reg add $pol /v ConsentPromptBehaviorAdmin      /t REG_DWORD /d 0 /f | Out-Null
& reg add $pol /v PromptOnSecureDesktop           /t REG_DWORD /d 0 /f | Out-Null
& reg add $pol /v FilterAdministratorToken        /t REG_DWORD /d 0 /f | Out-Null
& reg add $pol /v LocalAccountTokenFilterPolicy   /t REG_DWORD /d 1 /f | Out-Null

$def = 'HKLM\OFFSW\Microsoft\Windows Defender\Features'
& reg add $def /v TamperProtection       /t REG_DWORD /d 0 /f | Out-Null
& reg add $def /v TamperProtectionSource /t REG_DWORD /d 2 /f | Out-Null

$np = 'HKLM\OFFSW\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection'
& reg add $np /v EnableNetworkProtection /t REG_DWORD /d 1 /f | Out-Null

& reg add 'HKLM\OFFSW\Microsoft\Windows\CurrentVersion\Explorer' /v SmartScreenEnabled /t REG_SZ /d On /f | Out-Null
& reg add 'HKLM\OFFSW\Policies\Microsoft\Edge'                   /v SmartScreenEnabled /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[6/7] Unloading hive and dismounting..." -ForegroundColor Cyan
[gc]::Collect(); Start-Sleep 2
& reg unload HKLM\OFFSW | Out-Null
Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "${letter}:\" -ErrorAction SilentlyContinue
Dismount-VHD -Path $vhd

Write-Host "[7/7] Starting VM..." -ForegroundColor Cyan
Start-VM -Name $VMName

Write-Host ""
Write-Host "Done. Wait ~60s, then RDP to the VM:" -ForegroundColor Green
Write-Host "  mstsc /v:172.20.114.12"
Write-Host "After login, in PowerShell:" -ForegroundColor Green
Write-Host '  (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA  # expect 0'
Write-Host '  (Get-MpComputerStatus).IsTamperProtected   # expect False'
Write-Host '  (Get-MpPreference).EnableNetworkProtection # expect 1'
Write-Host '  whoami /groups | findstr /i "High Mandatory"'
