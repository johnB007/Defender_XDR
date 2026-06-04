# Fix-TamperProtection.ps1
# Re-mount non-mde VHD offline, take ownership of the Defender Features key,
# grant Administrators FullControl, then write TamperProtection=0.
# Run on the HOST in an elevated PowerShell window.

param([string]$VMName = 'non-mde')

$ErrorActionPreference = 'Stop'

# Enable SeTakeOwnershipPrivilege / SeRestorePrivilege / SeBackupPrivilege for this process
Add-Type -Namespace Win32 -Name Priv -MemberDefinition @'
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr h, uint da, out IntPtr tok);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool LookupPrivilegeValue(string s, string n, out long luid);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TOKPRIV p, int len, IntPtr prev, IntPtr rl);
[DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
[StructLayout(LayoutKind.Sequential, Pack=1)] public struct TOKPRIV { public int Count; public long Luid; public int Attr; }
'@ -Using System.Runtime.InteropServices
function Enable-Priv($name) {
  $tok = [IntPtr]::Zero
  [void][Win32.Priv]::OpenProcessToken([Win32.Priv]::GetCurrentProcess(), 0x28, [ref]$tok)
  $luid = 0L
  [void][Win32.Priv]::LookupPrivilegeValue($null, $name, [ref]$luid)
  $tp = New-Object Win32.Priv+TOKPRIV
  $tp.Count = 1; $tp.Luid = $luid; $tp.Attr = 2  # SE_PRIVILEGE_ENABLED
  [void][Win32.Priv]::AdjustTokenPrivileges($tok, $false, [ref]$tp, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}
Enable-Priv 'SeTakeOwnershipPrivilege'
Enable-Priv 'SeRestorePrivilege'
Enable-Priv 'SeBackupPrivilege'

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

Write-Host "[3/6] Loading SOFTWARE hive..." -ForegroundColor Cyan
& reg load HKLM\OFFSW "${letter}:\Windows\System32\config\SOFTWARE" | Out-Null

Write-Host "[4/6] Taking ownership of Defender\Features key..." -ForegroundColor Cyan
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

Write-Host "[5/6] Writing TamperProtection=0 ..." -ForegroundColor Cyan
& reg add 'HKLM\OFFSW\Microsoft\Windows Defender\Features' /v TamperProtection       /t REG_DWORD /d 0 /f
& reg add 'HKLM\OFFSW\Microsoft\Windows Defender\Features' /v TamperProtectionSource /t REG_DWORD /d 2 /f

Write-Host "[6/6] Unloading + dismounting + starting VM..." -ForegroundColor Cyan
[gc]::Collect(); Start-Sleep 2
& reg unload HKLM\OFFSW | Out-Null
Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "${letter}:\" -ErrorAction SilentlyContinue
Dismount-VHD -Path $vhd
Start-VM -Name $VMName

Write-Host ""
Write-Host "Done. Wait ~60s, RDP back and check:" -ForegroundColor Green
Write-Host '  (Get-MpComputerStatus).IsTamperProtected   # expect False'
