```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
  Azure Arc + MDE — US Gov DoD (IL5) Endpoint Connectivity Check

.DESCRIPTION
  Validates outbound connectivity from a Windows Server to the URLs Microsoft
  documents as required for:
    - Azure Arc-enabled servers onboarding (Azure Government)
    - Microsoft Defender for Endpoint (DoD)
    - Defender for Servers auto-onboarding of MDE via Arc

  Checks performed:
    1. DNS SOA lookups against the wildcard namespaces that use dynamic FQDNs
       (endpoint.security.microsoft.us, his.arc.azure.us, guestconfiguration.azure.us).
       These cannot be validated by TCP probes because the actual hostname is
       assigned at runtime; an SOA lookup confirms the resolver can reach the
       authoritative DNS zone.
    2. TCP connectivity to every required fixed FQDN on its required port.

  Sources:
    1. Arc network requirements (Azure Government tab)
       https://learn.microsoft.com/azure/azure-arc/servers/network-requirements
    2. MDE for US Government
       https://learn.microsoft.com/defender-endpoint/gov
    3. MDE streamlined URL list for Gov/GCC/DoD
       https://learn.microsoft.com/defender-endpoint/streamlined-device-connectivity-urls-gov

  Notes:
    - Wildcard domains (e.g. *.his.arc.azure.us) are tested via a real FQDN
      under that namespace AND via an SOA lookup. The firewall rule should
      still be written as the wildcard (or the appropriate Azure service tag).
    - Run as administrator on the target server.
    - If the environment uses an explicit HTTP proxy, results here reflect
      DIRECT connectivity. Use Invoke-WebRequest -Proxy to validate via proxy.

.PARAMETER TimeoutMs
  TCP connect timeout in milliseconds.
#>

param(
    [int]$TimeoutMs = 5000
)

# ─── Endpoint list (DoD / IL5 — US Gov Virginia) ──────────────────────────────
$endpoints = @(
    # ── Azure Arc core (Gov) ─────────────────────────────────────────────────
    @{ Host='login.microsoftonline.us';                               Port=443; Category='Arc - Entra ID';        DocRule='login.microsoftonline.us';            Source='1' }
    @{ Host='pasff.usgovcloudapi.net';                                Port=443; Category='Arc - Entra ID';        DocRule='pasff.usgovcloudapi.net';             Source='1' }
    @{ Host='management.usgovcloudapi.net';                           Port=443; Category='Arc - ARM';             DocRule='management.usgovcloudapi.net';        Source='1' }
    @{ Host='gbl.his.arc.azure.us';                                   Port=443; Category='Arc - HIS';             DocRule='*.his.arc.azure.us';                  Source='1' }
    @{ Host='agentserviceapi.guestconfiguration.azure.us';            Port=443; Category='Arc - Guest Config';    DocRule='*.guestconfiguration.azure.us';       Source='1' }
    @{ Host='onboardingpckgsusgvprd.blob.core.usgovcloudapi.net';     Port=443; Category='Arc - Extensions blob'; DocRule='*.blob.core.usgovcloudapi.net';       Source='1' }

    # ── Installation / certificate validation ────────────────────────────────
    @{ Host='download.microsoft.com';                                 Port=443; Category='Install';               DocRule='download.microsoft.com';              Source='1' }
    @{ Host='packages.microsoft.com';                                 Port=443; Category='Install';               DocRule='packages.microsoft.com';              Source='1' }
    @{ Host='www.microsoft.com';                                      Port=80;  Category='PKI / ESU certs';       DocRule='www.microsoft.com/pkiops/certs';      Source='1' }
    @{ Host='www.microsoft.com';                                      Port=443; Category='PKI / ESU certs';       DocRule='www.microsoft.com/pkiops/certs';      Source='1' }

    # ── MDE (DoD) ────────────────────────────────────────────────────────────
    @{ Host='winatp-gw-usgv.microsoft.us';                            Port=443; Category='MDE - Streamlined';     DocRule='*.endpoint.security.microsoft.us';    Source='3' }
    @{ Host='api-gov.securitycenter.microsoft.us';                    Port=443; Category='MDE - API';             DocRule='*.securitycenter.microsoft.us';       Source='2' }
    @{ Host='security.apps.mil';                                      Port=443; Category='MDE - Portal';          DocRule='security.apps.mil';                   Source='2' }
    @{ Host='unitedstates2.ss.wd.microsoft.us';                       Port=443; Category='MDE - SmartScreen';     DocRule='unitedstates2.ss.wd.microsoft.us';    Source='3' }

    # ── MDE Live Response ────────────────────────────────────────────────────
    @{ Host='client.wns.windows.com';                                 Port=443; Category='MDE - Live Response';   DocRule='*.wns.windows.com';                   Source='3' }
    @{ Host='login.live.com';                                         Port=443; Category='MDE - Live Response';   DocRule='login.live.com';                      Source='3' }
    @{ Host='login.microsoftonline.com';                              Port=443; Category='MDE - Live Response';   DocRule='login.microsoftonline.com';           Source='3' }

    # ── CRL / CTL ────────────────────────────────────────────────────────────
    @{ Host='crl.microsoft.com';                                      Port=80;  Category='PKI / CRL';             DocRule='crl.microsoft.com/pki/crl/*';         Source='3' }
    @{ Host='ctldl.windowsupdate.com';                                Port=80;  Category='PKI / CTL';             DocRule='ctldl.windowsupdate.com';             Source='3' }

    # ── MDAV signature/definition updates ────────────────────────────────────
    @{ Host='definitionupdates.microsoft.com';                        Port=443; Category='MDAV Updates';          DocRule='*.update.microsoft.com';              Source='3' }
    @{ Host='fe3cr.delivery.mp.microsoft.com';                        Port=443; Category='MDAV Updates';          DocRule='*.delivery.mp.microsoft.com';         Source='3' }
)

# ─── DNS pre-check zones (wildcards using dynamic FQDNs) ─────────────────────
$dnsChecks = @(
    @{ Zone='endpoint.security.microsoft.us'; Note='MDE streamlined namespace (dynamic FQDNs assigned at runtime)' }
    @{ Zone='his.arc.azure.us';               Note='Arc HIS namespace (dynamic FQDNs)' }
    @{ Zone='guestconfiguration.azure.us';    Note='Arc Guest Config namespace (dynamic FQDNs)' }
)

# ─── Source legend ───────────────────────────────────────────────────────────
$sourceMap = @{
    '1' = 'Arc network requirements (Gov) - https://learn.microsoft.com/azure/azure-arc/servers/network-requirements'
    '2' = 'MDE for US Government - https://learn.microsoft.com/defender-endpoint/gov'
    '3' = 'MDE streamlined URLs Gov/GCC/DoD - https://learn.microsoft.com/defender-endpoint/streamlined-device-connectivity-urls-gov'
}

# ─── Header ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Azure Arc + MDE — DoD (IL5) Connectivity Check" -ForegroundColor Cyan
Write-Host "  Target : $($env:COMPUTERNAME)" -ForegroundColor Gray
Write-Host "  Time   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "  Sources:" -ForegroundColor Gray
$sourceMap.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "    $($_.Key) = $($_.Value)" -ForegroundColor DarkGray
}
Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# ─── DNS pre-checks (SOA lookups) ────────────────────────────────────────────
$dnsResults = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Host ""
Write-Host "  DNS pre-checks (SOA lookups)" -ForegroundColor Cyan
foreach ($d in $dnsChecks) {
    Write-Host ("    {0,-45} " -f $d.Zone) -NoNewline
    $primary = ''
    try {
        $soa = Resolve-DnsName -Name $d.Zone -Type SOA -DnsOnly -ErrorAction Stop
        $primary = ($soa | Where-Object { $_.Type -eq 'SOA' } | Select-Object -First 1).PrimaryServer
        if ($primary) {
            Write-Host "[PASS]" -ForegroundColor Green -NoNewline
            Write-Host "  ($primary)" -ForegroundColor DarkGray
            $status = 'PASS'
        } else {
            Write-Host "[NODATA]" -ForegroundColor Yellow
            $status = 'NODATA'
        }
    } catch {
        Write-Host "[FAIL]" -ForegroundColor Red -NoNewline
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkGray
        $status = 'FAIL'
    }
    $dnsResults.Add([PSCustomObject]@{
        Zone          = $d.Zone
        PrimaryServer = $primary
        Status        = $status
        Note          = $d.Note
        Timestamp     = (Get-Date -Format 'o')
    })
}

# ─── TCP connectivity tests ──────────────────────────────────────────────────
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Host ""
Write-Host "  TCP connectivity tests" -ForegroundColor Cyan

$pass = 0; $fail = 0
foreach ($ep in $endpoints) {
    $label = "{0,-55} :{1}" -f $ep.Host, $ep.Port
    Write-Host "  [$($ep.Category)] $label " -NoNewline
    $status = 'FAIL'; $color = 'Red'
    try {
        $tcp  = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect($ep.Host, $ep.Port, $null, $null)
        $wait = $conn.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.EndConnect($conn)
            $status = 'PASS'; $color = 'Green'; $pass++
        } else { $fail++ }
        $tcp.Close()
    } catch {
        $status = 'ERROR'; $color = 'Yellow'; $fail++
    }
    Write-Host "[$status]" -ForegroundColor $color

    $results.Add([PSCustomObject]@{
        Category  = $ep.Category
        DocRule   = $ep.DocRule
        Host      = $ep.Host
        Port      = $ep.Port
        Status    = $status
        Source    = $ep.Source
        Timestamp = (Get-Date -Format 'o')
    })
}

# ─── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  TCP Results: $pass PASS  |  $fail FAIL" -ForegroundColor Cyan

# ─── Export ──────────────────────────────────────────────────────────────────
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$desktop   = [Environment]::GetFolderPath('Desktop')
$csv       = Join-Path $desktop "ArcMDE_DoD_IL5_Check_$timestamp.csv"
$dnsCsv    = Join-Path $desktop "ArcMDE_DoD_IL5_Check_${timestamp}_DNS.csv"

$results    | Export-Csv -Path $csv    -NoTypeInformation -Encoding UTF8
$dnsResults | Export-Csv -Path $dnsCsv -NoTypeInformation -Encoding UTF8

Write-Host "  Exported: $csv"    -ForegroundColor Gray
Write-Host "  Exported: $dnsCsv" -ForegroundColor Gray

# ─── Failure callouts ────────────────────────────────────────────────────────
$blocked = $results | Where-Object { $_.Status -ne 'PASS' }
if ($blocked) {
    Write-Host ""
    Write-Host "  Blocked / unreachable endpoints (firewall action required):" -ForegroundColor Red
    $blocked | ForEach-Object {
        Write-Host "    $($_.DocRule) (port $($_.Port))  ->  tested: $($_.Host)" -ForegroundColor Red
    }
}

$dnsFailed = $dnsResults | Where-Object { $_.Status -ne 'PASS' }
if ($dnsFailed) {
    Write-Host ""
    Write-Host "  DNS resolution failures (resolver / forwarder action required):" -ForegroundColor Red
    $dnsFailed | ForEach-Object {
        Write-Host "    $($_.Zone)  ->  $($_.Status)  ($($_.Note))" -ForegroundColor Red
    }
}

Write-Host ""
```
