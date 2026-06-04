# Run inside the Hyper-V VM as Administrator (PowerShell 5.1 or 7).
# Diagnoses and repairs the Hyper-V Remote Desktop Virtualization service (vmicrdv)
# so Enhanced Session can negotiate. Reboots when done.

$ErrorActionPreference = 'Continue'

Write-Host '==== Hostname ====' -ForegroundColor Cyan
hostname

Write-Host "`n==== vmicrdv state ====" -ForegroundColor Cyan
Get-Service vmicrdv | Format-List Name, Status, StartType, DisplayName

Write-Host "`n==== Recent System events mentioning vmicrdv ====" -ForegroundColor Cyan
Get-WinEvent -LogName System -MaxEvents 200 -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -like '*vmicrdv*' -or $_.Message -like '*vmicrdv*' -or $_.Message -like '*Remote Desktop Virtualization*' } |
    Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message |
    Format-List

Write-Host "`n==== HV synthetic RDP device ====" -ForegroundColor Cyan
Get-PnpDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -like '*RDP*' -or $_.FriendlyName -like '*Synthetic*' -or $_.HardwareID -like '*VMBus*RDV*' } |
    Format-Table FriendlyName, Status, Class, InstanceId -AutoSize

Write-Host "`n==== Re-register vmbus RDV driver ====" -ForegroundColor Cyan
$inf = Get-ChildItem 'C:\Windows\INF\vmbusrdv*.inf' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($inf) {
    pnputil /add-driver $inf.FullName /install
} else {
    Write-Host 'vmbusrdv.inf not present. Trying generic vmbus inf set.' -ForegroundColor Yellow
    Get-ChildItem 'C:\Windows\INF\vmbus*.inf' -ErrorAction SilentlyContinue | ForEach-Object { pnputil /add-driver $_.FullName /install }
}

Write-Host "`n==== Service recovery: auto-restart on failure ====" -ForegroundColor Cyan
sc.exe failure vmicrdv reset= 0 actions= restart/5000/restart/5000/restart/5000
sc.exe config vmicrdv start= auto

Write-Host "`n==== Trying to start vmicrdv ====" -ForegroundColor Cyan
sc.exe start vmicrdv
Start-Sleep -Seconds 3
Get-Service vmicrdv | Format-List Name, Status, StartType

Write-Host "`n==== Rebooting in 10 seconds. Ctrl+C to cancel. ====" -ForegroundColor Yellow
Start-Sleep -Seconds 10
shutdown /r /t 0
