<#
.SYNOPSIS
    Generates every Event ID the SYSVOL-DC-Replication-Monitor workbook queries.

.DESCRIPTION
    Writes synthetic Information / Warning / Error events into the real channels
    (DFS Replication, Directory Service, System, Application, Security).
    Also performs real service stop/start operations to produce authentic
    DFSR and NTDS lifecycle events.

    Run as Administrator on a Domain Controller.

.NOTES
    Lab use only. Synthetic events have a recognizable [SYNTHETIC-TEST] tag in
    their message body so you can filter them out later if needed.
#>

[CmdletBinding()]
param(
    [switch]$SkipServiceRestarts,    # skip the real Stop/Start NTDS + DFSR
    [switch]$SkipBadLogon            # skip the 4625 generation
)

#region helpers ---------------------------------------------------------------

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Register-LogSource {
    param([string]$LogName, [string]$Source)
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
            New-EventLog -LogName $LogName -Source $Source -ErrorAction Stop
            Write-Host "  [+] registered source '$Source' on log '$LogName'" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [!] could not register '$Source' on '$LogName': $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Emit {
    param(
        [string]$LogName,
        [string]$Source,
        [int]$EventId,
        [ValidateSet('Information','Warning','Error')] [string]$Type = 'Information',
        [string]$Message
    )
    $msg = "[SYNTHETIC-TEST] $Message"
    try {
        Write-EventLog -LogName $LogName -Source $Source -EventId $EventId `
            -EntryType $Type -Message $msg -ErrorAction Stop
        Write-Host ("  [{0,-7}] {1,-20} EID {2,-5} -> {3}" -f $Type, $LogName, $EventId, $Message)
    } catch {
        Write-Host "  [!] EID $EventId on $LogName failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

#endregion

if (-not (Test-IsAdmin)) {
    throw "Must run elevated (Administrator)."
}

Write-Host "==> Registering synthetic event sources..." -ForegroundColor Cyan
Register-LogSource -LogName "Directory Service" -Source "SyntheticDS"
Register-LogSource -LogName "DFS Replication"   -Source "SyntheticDFSR"
Register-LogSource -LogName "System"            -Source "SyntheticSys"
Register-LogSource -LogName "Application"       -Source "SyntheticApp"

#region Directory Service catalog --------------------------------------------
# IDs the workbook references on the Directory Service channel.
$DirectoryServiceCatalog = @(
    @{ Id=1168; Type='Error';   Msg='NTDS internal processing error' }
    @{ Id=1173; Type='Error';   Msg='Internal event: directory service could not allocate a relative identifier' }
    @{ Id=1202; Type='Warning'; Msg='Security policy in Group Policy objects has been applied' }
    @{ Id=1206; Type='Warning'; Msg='NTDS replication latency above threshold' }
    @{ Id=1311; Type='Error';   Msg='KCC could not compute spanning tree for site' }
    @{ Id=1388; Type='Error';   Msg='Lingering object detected on naming context' }
    @{ Id=1645; Type='Error';   Msg='AD did not perform authenticated RPC to remote DC' }
    @{ Id=1655; Type='Error';   Msg='AD attempted to communicate with the following GC and the attempts were unsuccessful' }
    @{ Id=1864; Type='Warning'; Msg='Replication summary status' }
    @{ Id=1866; Type='Warning'; Msg='KCC connection object problem detected' }
    @{ Id=1925; Type='Warning'; Msg='Failed to establish replication link, naming context' }
    @{ Id=1926; Type='Warning'; Msg='Replication source DC unreachable' }
    @{ Id=2042; Type='Error';   Msg='Replication has been stopped with this source for tombstone lifetime' }
    @{ Id=2087; Type='Error';   Msg='AD could not resolve DNS host name of source DC' }
    @{ Id=2088; Type='Warning'; Msg='AD used NetBIOS fallback to resolve source DC' }
    @{ Id=5805; Type='Error';   Msg='Session setup failed; computer denied access' }
)
Write-Host "`n==> Directory Service events..." -ForegroundColor Cyan
foreach ($e in $DirectoryServiceCatalog) {
    Emit -LogName 'Directory Service' -Source 'SyntheticDS' -EventId $e.Id -Type $e.Type -Message $e.Msg
}
#endregion

#region DFS Replication catalog ----------------------------------------------
# IDs the workbook references on the DFS Replication channel.
$DfsrCatalog = @(
    @{ Id=1202; Type='Information'; Msg='DFSR service started' }
    @{ Id=1206; Type='Information'; Msg='DFSR service stopped' }
    @{ Id=2104; Type='Error';   Msg='Failed to recover database for replicated folder SYSVOL Share' }
    @{ Id=2212; Type='Error';   Msg='DFSR has paused replication due to disk space exhaustion' }
    @{ Id=2213; Type='Error';   Msg='DFSR database needs manual resume after dirty shutdown' }
    @{ Id=2214; Type='Warning'; Msg='Auto-recovery initiated for DFSR database' }
    @{ Id=4002; Type='Error';   Msg='DFSR conflict during replication' }
    @{ Id=4004; Type='Error';   Msg='DFSR could not contact partner' }
    @{ Id=4012; Type='Error';   Msg='DFSR stopped replicating with partner past tombstone window (MaxOfflineTimeInDays)' }
    @{ Id=4202; Type='Warning'; Msg='Sharing violation on SYSVOL replicated file' }
    @{ Id=4204; Type='Warning'; Msg='File excluded from replication' }
    @{ Id=4412; Type='Warning'; Msg='Conflict-and-deleted folder cleanup' }
    @{ Id=4414; Type='Warning'; Msg='File replication conflict resolved' }
    @{ Id=5002; Type='Error';   Msg='DFSR encountered an error communicating with partner' }
    @{ Id=5004; Type='Warning'; Msg='DFSR connection re-established with partner' }
    @{ Id=5008; Type='Error';   Msg='DFSR could not communicate with partner over RPC' }
    @{ Id=6016; Type='Error';   Msg='DFSR replication folder contained unreferenced data' }
    @{ Id=6018; Type='Warning'; Msg='DFSR cleanup completed for replicated folder' }
)
Write-Host "`n==> DFS Replication events..." -ForegroundColor Cyan
foreach ($e in $DfsrCatalog) {
    Emit -LogName 'DFS Replication' -Source 'SyntheticDFSR' -EventId $e.Id -Type $e.Type -Message $e.Msg
}
#endregion

#region System / Application sanity events -----------------------------------
Write-Host "`n==> System / Application sanity events..." -ForegroundColor Cyan
Emit -LogName 'System'      -Source 'SyntheticSys' -EventId 7036 -Type 'Information' -Msg 'Synthetic service state change'
Emit -LogName 'Application' -Source 'SyntheticApp' -EventId 1000 -Type 'Information' -Msg 'Synthetic application heartbeat'
#endregion

#region Real service-driven events -------------------------------------------
if (-not $SkipServiceRestarts) {
    Write-Host "`n==> Real DFSR service stop/start (will produce authentic 1002/1004/1006/1008)..." -ForegroundColor Cyan
    try {
        Stop-Service DFSR -Force -ErrorAction Stop
        Start-Sleep -Seconds 5
        Start-Service DFSR -ErrorAction Stop
        Write-Host "  [+] DFSR restarted"
    } catch { Write-Host "  [!] DFSR restart failed: $($_.Exception.Message)" -ForegroundColor Yellow }

    Write-Host "`n==> Real NTDS service stop/start (will produce Directory Service shutdown/startup events)..." -ForegroundColor Cyan
    try {
        Stop-Service NTDS -Force -ErrorAction Stop
        Start-Sleep -Seconds 5
        Start-Service NTDS -ErrorAction Stop
        Write-Host "  [+] NTDS restarted"
    } catch { Write-Host "  [!] NTDS restart failed: $($_.Exception.Message)" -ForegroundColor Yellow }
}
#endregion

#region Security channel: real 4624 / 4625 / 4672 ----------------------------
# 4624/4672 happen on every successful elevated logon; running this script already
# generated them. We can force a 4625 (failed logon) with a bad credential.
if (-not $SkipBadLogon) {
    Write-Host "`n==> Generating Security 4625 (failed logon)..." -ForegroundColor Cyan
    try {
        $u = "bogus_$(Get-Random)"
        $p = ConvertTo-SecureString 'WrongPass!123' -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($u,$p)
        Start-Process -FilePath cmd.exe -ArgumentList '/c exit' -Credential $cred `
            -WorkingDirectory 'C:\' -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  [+] forced bad logon attempt as user '$u'"
    } catch {
        Write-Host "  [+] bad logon attempted (expected to fail): $($_.Exception.Message)"
    }

    Write-Host "==> Generating Kerberos 4768/4769/4771 by hitting AD..." -ForegroundColor Cyan
    try {
        klist purge | Out-Null
        nltest /sc_query:$env:USERDNSDOMAIN | Out-Null
        Get-ADUser -Filter * -ResultSetSize 1 | Out-Null
        Write-Host "  [+] kerberos ticket activity triggered"
    } catch {
        Write-Host "  [!] kerberos trigger failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
#endregion

Write-Host "`n==> Done. Wait 5-10 minutes for AMA to ship to Log Analytics, then refresh the workbook." -ForegroundColor Green
Write-Host "    Filter synthetic rows in KQL with:  | where RenderedDescription !contains '[SYNTHETIC-TEST]'" -ForegroundColor DarkGray
