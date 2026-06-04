<#
.SYNOPSIS
    Validate MDE URL/Domain IOCs by detonating each one on a lab host with
    Network Protection (NP) and SmartScreen enabled, then reading local
    event logs to see what blocked it.

.DESCRIPTION
    Reads an MDE indicator export (CSV or XLSX) untouched. For each Url or
    DomainName row it does a DNS lookup plus an HTTP(S) request, waits for
    Defender to flush its events, then scans:

      - Microsoft-Windows-Windows Defender/Operational (event IDs 1125 audit,
        1126 block) for Network Protection verdicts.
      - Microsoft-Windows-SmartScreen/Debug (if present) for SmartScreen
        verdicts.

    Outputs Url_Validated_<timestamp>.xlsx with three sheets:
        Summary, Already Covered by NP/SmartScreen, All Indicators.

    No cloud auth required. Everything runs locally on the lab host.

.NOTES
    Run as Administrator on a Windows host with:
      - Microsoft Defender Antivirus active (not third-party AV)
      - Network Protection enabled in Block (1) or Audit (2) mode
        Set-MpPreference -EnableNetworkProtection 1
      - SmartScreen enabled (default on Win10/11)

    The script will refuse to run if NP is disabled.

.PARAMETER InputPath
    Path to the MDE indicator CSV/XLSX. Defaults to the newest non-Validated
    file in the script folder.

.PARAMETER OutputPath
    Path for the output .xlsx. Defaults to <input>_Validated_<timestamp>.xlsx.

.PARAMETER PerIndicatorDelayMs
    Time to wait after detonation before reading event logs. Default 2500 ms.

.PARAMETER HttpTimeoutSec
    HTTP request timeout. Default 5 seconds.

.EXAMPLE
    .\Validate-UrlDomainIpIOCs.ps1
#>

[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$OutputPath,
    [int]$PerIndicatorDelayMs = 2500,
    [int]$HttpTimeoutSec = 5
)

# --- Admin + module checks --------------------------------------------------

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Run this script as Administrator. Defender event logs require elevated access."
    exit 1
}

$mod = Get-Module -ListAvailable -Name ImportExcel | Sort-Object Version -Descending | Select-Object -First 1
if (-not $mod) {
    Write-Host ""
    Write-Host "ImportExcel is not installed. Install it once, then re-run this script:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After it finishes, close this window and open a new PowerShell window before running the script again." -ForegroundColor Yellow
    exit 1
}
Import-Module $mod.Path -ErrorAction Stop

# --- Defender preflight -----------------------------------------------------

try {
    $mp = Get-MpPreference -ErrorAction Stop
} catch {
    Write-Error "Get-MpPreference failed. Is Microsoft Defender Antivirus active on this host? $_"
    exit 1
}

$npMode = $mp.EnableNetworkProtection
$npLabel = switch ($npMode) { 0 {'Disabled'} 1 {'Block'} 2 {'Audit'} default {"Unknown($npMode)"} }
Write-Host "Network Protection mode: $npLabel" -ForegroundColor Cyan
if ($npMode -eq 0) {
    Write-Error "Network Protection is disabled. Enable it first: Set-MpPreference -EnableNetworkProtection 1"
    exit 1
}

# SmartScreen: check Explorer shell SmartScreen + Edge SmartScreen
function Get-SmartScreenState {
    $shell = 'Off'
    try {
        $v = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name SmartScreenEnabled -ErrorAction Stop).SmartScreenEnabled
        if ($v -in 'RequireAdmin','Warn','Prompt','On') { $shell = $v }
    } catch {}

    $edge = 'Off'
    try {
        $v = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name SmartScreenEnabled -ErrorAction Stop).SmartScreenEnabled
        if ($v -eq 1) { $edge = 'On (policy)' }
    } catch {}
    if ($edge -eq 'Off') {
        try {
            $v = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Edge\SmartScreenEnabled' -ErrorAction Stop).'(default)'
            if ($v -eq 1) { $edge = 'On' }
        } catch {}
        # Edge default is On unless policy disables it
        if ($edge -eq 'Off') { $edge = 'On (default)' }
    }

    [PSCustomObject]@{ Shell = $shell; Edge = $edge }
}

$ss = Get-SmartScreenState
Write-Host "SmartScreen (Shell): $($ss.Shell)" -ForegroundColor Cyan
Write-Host "SmartScreen (Edge):  $($ss.Edge)"  -ForegroundColor Cyan
if ($ss.Shell -eq 'Off' -and $ss.Edge -like 'Off*') {
    Write-Error "SmartScreen is disabled in both the Windows shell and Edge. Enable it under Windows Security, App & browser control, Reputation-based protection."
    exit 1
}

$mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($mpStatus) {
    Write-Host "MDAV signature: $($mpStatus.AntivirusSignatureVersion) (updated $($mpStatus.AntivirusSignatureLastUpdated))" -ForegroundColor Cyan
}

# --- Locate input file ------------------------------------------------------

if (-not $InputPath) {
    $candidate = Get-ChildItem -Path $PSScriptRoot -File |
        Where-Object { $_.Extension -in '.csv','.xlsx' -and $_.Name -notmatch 'Validated' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $candidate) {
        Write-Error "No .csv or .xlsx file found in $PSScriptRoot. Drop your MDE URL/Domain export here and rerun."
        exit 1
    }
    $InputPath = $candidate.FullName
}
Write-Host "Input file: $InputPath" -ForegroundColor Cyan

if (-not $OutputPath) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $base = [IO.Path]::GetFileNameWithoutExtension($InputPath)
    $OutputPath = Join-Path (Split-Path $InputPath) ("{0}_Validated_{1}.xlsx" -f $base, $stamp)
}

# --- Load rows --------------------------------------------------------------

if ([IO.Path]::GetExtension($InputPath) -ieq '.xlsx') {
    $rows = Import-Excel -Path $InputPath
} else {
    $rows = Import-Csv -Path $InputPath
}

if (-not $rows) { Write-Error "No rows loaded from $InputPath"; exit 1 }

function Get-ColumnValue {
    param($Row, [string[]]$Names)
    foreach ($n in $Names) {
        $p = $Row.PSObject.Properties[$n]
        if ($p -and $p.Value) { return [string]$p.Value }
    }
    return $null
}

function Get-IndicatorType {
    param([string]$Value, [string]$DeclaredType)
    if ($DeclaredType) {
        switch -Regex ($DeclaredType) {
            'Url'        { return 'Url' }
            'Domain'     { return 'DomainName' }
            'IpAddress'  { return 'IpAddress' }
        }
    }
    if ($Value -match '^https?://') { return 'Url' }
    if ($Value -match '^\d{1,3}(\.\d{1,3}){3}$') { return 'IpAddress' }
    return 'DomainName'
}

function Get-Host {
    param([string]$Value)
    if ($Value -match '^https?://') {
        try { return ([Uri]$Value).Host } catch { return $Value }
    }
    return ($Value -replace '^\*\.','' -replace '/.*$','')
}

# --- Detonation -------------------------------------------------------------

function Invoke-Detonation {
    param([string]$Indicator, [string]$Type, [int]$TimeoutSec)

    $result = [ordered]@{
        DnsResolved = $false
        HttpStatus  = ''
        Error       = ''
    }

    $targetHost = Get-Host -Value $Indicator
    try {
        $dns = Resolve-DnsName -Name $targetHost -DnsOnly -ErrorAction Stop
        $result.DnsResolved = [bool]$dns
    } catch {
        $result.Error = "DNS: $($_.Exception.Message)"
    }

    if ($Type -eq 'Url' -or $Type -eq 'DomainName') {
        $url = if ($Indicator -match '^https?://') { $Indicator } else { "http://$targetHost/" }
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec -MaximumRedirection 0 -ErrorAction Stop
            $result.HttpStatus = [int]$r.StatusCode
        } catch [System.Net.WebException] {
            if ($_.Exception.Response) {
                $result.HttpStatus = [int]$_.Exception.Response.StatusCode
            } else {
                $result.HttpStatus = 'NoResponse'
            }
            $result.Error = $_.Exception.Message
        } catch {
            $result.HttpStatus = 'Error'
            $result.Error = $_.Exception.Message
        }
    } elseif ($Type -eq 'IpAddress') {
        try {
            $tcp = Test-NetConnection -ComputerName $targetHost -Port 443 -WarningAction SilentlyContinue
            $result.HttpStatus = if ($tcp.TcpTestSucceeded) { 'TcpOpen' } else { 'TcpBlocked' }
        } catch { $result.Error = $_.Exception.Message }
    }

    return [PSCustomObject]$result
}

# --- Event log lookups ------------------------------------------------------

function Get-NpVerdict {
    param([string]$HostOrUrl, [datetime]$Since)

    $filter = @{
        LogName   = 'Microsoft-Windows-Windows Defender/Operational'
        StartTime = $Since
        Id        = 1125,1126
    }
    try {
        $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop -MaxEvents 200
    } catch { return $null }

    $needle = [regex]::Escape($HostOrUrl.ToLower())
    $match = $events | Where-Object { $_.Message.ToLower() -match $needle } | Select-Object -First 1
    if (-not $match) { return $null }

    $status = if ($match.Id -eq 1126) { 'Blocked' } else { 'Audited' }
    [PSCustomObject]@{
        Status     = $status
        EventId    = $match.Id
        EventTime  = $match.TimeCreated
        ThreatName = ($match.Message -split "`n" | Where-Object { $_ -match 'Threat\s*name' } | Select-Object -First 1) -replace '.*:\s*',''
        Raw        = ($match.Message -replace "`r?`n",' | ').Substring(0, [Math]::Min(400, $match.Message.Length))
    }
}

function Get-SmartScreenVerdict {
    param([string]$HostOrUrl, [datetime]$Since)

    $candidates = @(
        'Microsoft-Windows-SmartScreen/Debug',
        'Microsoft-Windows-AppHost/Admin'
    )
    foreach ($log in $candidates) {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName=$log; StartTime=$Since } -ErrorAction Stop -MaxEvents 200
        } catch { continue }

        $needle = [regex]::Escape($HostOrUrl.ToLower())
        $match = $events | Where-Object { $_.Message -and $_.Message.ToLower() -match $needle } | Select-Object -First 1
        if ($match) {
            return [PSCustomObject]@{
                Status    = 'Flagged'
                EventTime = $match.TimeCreated
                Source    = $log
                Raw       = ($match.Message -replace "`r?`n",' | ').Substring(0, [Math]::Min(400, $match.Message.Length))
            }
        }
    }
    return $null
}

# --- Main loop --------------------------------------------------------------

$results = New-Object System.Collections.Generic.List[object]
$i = 0
foreach ($row in $rows) {
    $i++
    $value = Get-ColumnValue $row @('Indicator Value','IndicatorValue','Url','Domain','Indicator')
    if (-not $value) { continue }
    $declared = Get-ColumnValue $row @('Indicator Type','IndicatorType','Type')
    $type = Get-IndicatorType -Value $value -DeclaredType $declared
    $targetHost = Get-Host -Value $value

    Write-Host ("[{0}/{1}] {2} ({3})" -f $i, $rows.Count, $value, $type) -ForegroundColor White

    $startTime = (Get-Date).AddSeconds(-2)
    $det = Invoke-Detonation -Indicator $value -Type $type -TimeoutSec $HttpTimeoutSec
    Start-Sleep -Milliseconds $PerIndicatorDelayMs

    $np = Get-NpVerdict -HostOrUrl $targetHost -Since $startTime
    $ss = Get-SmartScreenVerdict -HostOrUrl $targetHost -Since $startTime

    $verdict =
        if     ($np -and $np.Status -eq 'Blocked')  { 'Covered-NP-Block' }
        elseif ($np -and $np.Status -eq 'Audited')  { 'Covered-NP-Audit' }
        elseif ($ss)                                { 'Covered-SmartScreen' }
        elseif ($det.Error -and -not $det.DnsResolved) { 'Error-NoResolution' }
        else                                        { 'Not-Covered-Keep-In-MDE' }

    $results.Add([PSCustomObject]@{
        IndicatorValue       = $value
        IndicatorType        = $type
        TargetHost           = $targetHost
        DnsResolved          = $det.DnsResolved
        HttpStatus           = $det.HttpStatus
        NpStatus             = if ($np) { $np.Status } else { 'NotTriggered' }
        NpEventId            = if ($np) { $np.EventId } else { '' }
        NpEventTime          = if ($np) { $np.EventTime } else { '' }
        NpThreatName         = if ($np) { $np.ThreatName } else { '' }
        SmartScreenStatus    = if ($ss) { $ss.Status } else { 'NotTriggered' }
        SmartScreenEventTime = if ($ss) { $ss.EventTime } else { '' }
        SmartScreenSource    = if ($ss) { $ss.Source } else { '' }
        OverallVerdict       = $verdict
        DetonationError      = $det.Error
        NpRaw                = if ($np) { $np.Raw } else { '' }
    }) | Out-Null
}

# --- Output -----------------------------------------------------------------

$summary = [PSCustomObject]@{
    HostName                = $env:COMPUTERNAME
    RunTime                 = Get-Date
    NetworkProtectionMode   = $npLabel
    SmartScreenShell        = $ss.Shell
    SmartScreenEdge         = $ss.Edge
    MdavSignatureVersion    = if ($mpStatus) { $mpStatus.AntivirusSignatureVersion } else { '' }
    TotalIndicators         = $results.Count
    CoveredNPBlock          = ($results | Where-Object OverallVerdict -eq 'Covered-NP-Block').Count
    CoveredNPAudit          = ($results | Where-Object OverallVerdict -eq 'Covered-NP-Audit').Count
    CoveredSmartScreen      = ($results | Where-Object OverallVerdict -eq 'Covered-SmartScreen').Count
    NotCovered              = ($results | Where-Object OverallVerdict -eq 'Not-Covered-Keep-In-MDE').Count
    Errors                  = ($results | Where-Object OverallVerdict -like 'Error*').Count
    InputFile               = $InputPath
}

if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }
$summary | Export-Excel -Path $OutputPath -WorksheetName 'Summary' -AutoSize -BoldTopRow
$results | Where-Object OverallVerdict -like 'Covered*' |
    Export-Excel -Path $OutputPath -WorksheetName 'Already Covered by NP-SmartScreen' -AutoSize -BoldTopRow
$results | Export-Excel -Path $OutputPath -WorksheetName 'All Indicators' -AutoSize -BoldTopRow -FreezeTopRow

Write-Host ""
Write-Host "Done. Output: $OutputPath" -ForegroundColor Green
Write-Host ("  NP-Block:  {0}" -f $summary.CoveredNPBlock)         -ForegroundColor Green
Write-Host ("  NP-Audit:  {0}" -f $summary.CoveredNPAudit)         -ForegroundColor Green
Write-Host ("  SmartScrn: {0}" -f $summary.CoveredSmartScreen)     -ForegroundColor Green
Write-Host ("  KeepInMDE: {0}" -f $summary.NotCovered)             -ForegroundColor Yellow
Write-Host ("  Errors:    {0}" -f $summary.Errors)                 -ForegroundColor Yellow

Start-Process $OutputPath
