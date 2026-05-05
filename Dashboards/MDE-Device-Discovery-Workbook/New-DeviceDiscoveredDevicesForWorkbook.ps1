<#
.SYNOPSIS
    Validates every KQL tile in the MDE Device Discovery workbook by running each
    query against the Microsoft Defender Advanced Hunting API.

.DESCRIPTION
    Reads MDE-Device-Discovery-Inventory.json, extracts all KqlItem queries,
    substitutes workbook parameter placeholders ({TimeRange}, {DeviceFilter}, etc.)
    with test values, and submits each query to the Advanced Hunting REST API.

    Reports PASS / FAIL / EMPTY for each tile with row count and elapsed time, and
    writes a CSV result file for review. Designed to run on a lab Windows 11 box.

.PARAMETER WorkbookPath
    Full path to MDE-Device-Discovery-Inventory.json. Defaults to the sibling JSON.

.PARAMETER TimeRange
    KQL time predicate to substitute for {TimeRange}. Default uses last 7 days for
    speed. Use 'between (ago(30d) .. now())' for full coverage.

.PARAMETER OutDir
    Directory to write the CSV result and per-tile error log. Defaults to .\TestResults.

.PARAMETER TenantId
    Entra tenant ID for token acquisition. Optional if you already have a token
    (then pass -AccessToken).

.PARAMETER AccessToken
    Bearer token for https://api.security.microsoft.com. If omitted, the script
    runs an interactive device-code login.

.PARAMETER Skip
    Optional list of tile names (the "name" field in the workbook JSON) to skip.

.EXAMPLE
    .\Test-Workbook.ps1
    Runs all tiles with last 7 days time range, interactive login.

.EXAMPLE
    .\Test-Workbook.ps1 -TimeRange 'between (ago(24h) .. now())' -Verbose
    Quick smoke test against a 24h window.

.NOTES
    Requires:
        - PowerShell 7+ (or 5.1)
        - An Entra account with the AdvancedHunting.Read.All permission OR a
          delegated security role (Security Reader / Security Administrator).
        - Outbound HTTPS to login.microsoftonline.com and api.security.microsoft.com.

    Advanced Hunting limits per query:
        - 10,000 rows max
        - 10 minute timeout
        - 100 MB result size

    DeviceInfo retention in AH is 30 days.
#>

[CmdletBinding()]
param(
    [string]$WorkbookPath = (Join-Path $PSScriptRoot 'MDE-Device-Discovery-Inventory.json'),
    [string]$TimeRange   = 'between (ago(7d) .. now())',
    [string]$DeviceFilter = '',
    [string]$IPFilter    = '',
    [string]$MACFilter   = '',
    [int]   $RowLimit    = 1000,
    [string]$OutDir      = (Join-Path $PSScriptRoot 'TestResults'),
    [string]$TenantId    = 'common',
    [string]$AccessToken,
    [string[]]$Skip      = @()
)

$ErrorActionPreference = 'Stop'

# ---------- Setup ----------
if (-not (Test-Path $WorkbookPath)) {
    throw "Workbook JSON not found at $WorkbookPath"
}
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$RunId    = (Get-Date -Format 'yyyyMMdd-HHmmss')
$CsvPath  = Join-Path $OutDir "TileResults-$RunId.csv"
$ErrPath  = Join-Path $OutDir "TileErrors-$RunId.log"

Write-Host "Workbook  : $WorkbookPath"
Write-Host "TimeRange : $TimeRange"
Write-Host "Results   : $CsvPath"
Write-Host ""

# ---------- Token acquisition (device code flow) ----------
function Get-AhToken {
    param([string]$TenantId)

    $clientId = '1950a258-227b-4e31-a9cf-717495945fc2'  # well-known Azure PowerShell client
    $resource = 'https://api.security.microsoft.com'
    $scope    = "$resource/.default offline_access"

    Write-Host "Starting device code login for $resource ..."
    $deviceCodeUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode"
    $body = @{ client_id = $clientId; scope = $scope }
    $dc = Invoke-RestMethod -Method Post -Uri $deviceCodeUri -Body $body

    Write-Host ""
    Write-Host "  $($dc.message)" -ForegroundColor Yellow
    Write-Host ""

    $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $stop = (Get-Date).AddSeconds([int]$dc.expires_in)
    while ((Get-Date) -lt $stop) {
        Start-Sleep -Seconds [Math]::Max(5, [int]$dc.interval)
        try {
            $tok = Invoke-RestMethod -Method Post -Uri $tokenUri -Body @{
                grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
                client_id   = $clientId
                device_code = $dc.device_code
            } -ErrorAction Stop
            Write-Host "Token acquired." -ForegroundColor Green
            return $tok.access_token
        } catch {
            $err = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($err -and $err.error -eq 'authorization_pending') { continue }
            if ($err -and $err.error -eq 'slow_down')             { Start-Sleep 5; continue }
            throw $_
        }
    }
    throw 'Device code login timed out.'
}

if (-not $AccessToken) {
    $AccessToken = Get-AhToken -TenantId $TenantId
}

# ---------- Workbook walk ----------
$wb = Get-Content $WorkbookPath -Raw | ConvertFrom-Json -Depth 100

function Get-KqlTiles {
    param($Items)
    foreach ($it in $Items) {
        if ($it.type -eq 3 -and $it.content.query) {
            [pscustomobject]@{
                Name  = $it.name
                Title = $it.content.title
                Query = $it.content.query
            }
        }
        if ($it.content -and $it.content.items) {
            Get-KqlTiles -Items $it.content.items
        }
    }
}

$tiles = @(Get-KqlTiles -Items $wb.items)
Write-Host "Found $($tiles.Count) KQL tile(s)."
Write-Host ""

# ---------- Substitute workbook parameters ----------
function Resolve-Query {
    param([string]$Q)
    $Q = $Q -replace '\{TimeRange\}',    $TimeRange
    $Q = $Q -replace '\{DeviceFilter\}', $DeviceFilter
    $Q = $Q -replace '\{IPFilter\}',     $IPFilter
    $Q = $Q -replace '\{MACFilter\}',    $MACFilter
    $Q = $Q -replace '\{RowLimit\}',     $RowLimit
    return $Q
}

# ---------- AH runner ----------
$AhEndpoint = 'https://api.security.microsoft.com/api/advancedhunting/run'
$Headers = @{
    Authorization = "Bearer $AccessToken"
    'Content-Type' = 'application/json'
}

$results = New-Object System.Collections.Generic.List[object]
$idx = 0

foreach ($tile in $tiles) {
    $idx++
    if ($Skip -contains $tile.Name) {
        Write-Host "[$idx/$($tiles.Count)] SKIP $($tile.Name)" -ForegroundColor DarkGray
        continue
    }

    $resolved = Resolve-Query -Q $tile.Query
    $payload  = @{ Query = $resolved } | ConvertTo-Json -Depth 5 -Compress

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $status = 'PASS'; $rows = 0; $errMsg = ''

    try {
        $resp = Invoke-RestMethod -Method Post -Uri $AhEndpoint -Headers $Headers -Body $payload -ErrorAction Stop
        $rows = if ($resp.Results) { @($resp.Results).Count } else { 0 }
        if ($rows -eq 0) { $status = 'EMPTY' }
    } catch {
        $status = 'FAIL'
        $errMsg = $_.Exception.Message
        try {
            if ($_.ErrorDetails.Message) {
                $j = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($j.error.message) { $errMsg = $j.error.message }
            }
        } catch {}
        Add-Content -Path $ErrPath -Value "===== $($tile.Name) =====`n$errMsg`n`nQuery:`n$resolved`n`n"
    }
    $sw.Stop()

    $color = switch ($status) { 'PASS'{'Green'} 'EMPTY'{'Yellow'} 'FAIL'{'Red'} default{'White'} }
    Write-Host ("[{0}/{1}] {2,-5} {3,6}ms {4,7} rows  {5}" -f $idx, $tiles.Count, $status, $sw.ElapsedMilliseconds, $rows, $tile.Name) -ForegroundColor $color

    $results.Add([pscustomobject]@{
        Index    = $idx
        Name     = $tile.Name
        Title    = $tile.Title
        Status   = $status
        Rows     = $rows
        Elapsed_ms = $sw.ElapsedMilliseconds
        Error    = $errMsg
    })
}

# ---------- Summary ----------
$results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

$pass  = ($results | Where-Object Status -eq 'PASS').Count
$empty = ($results | Where-Object Status -eq 'EMPTY').Count
$fail  = ($results | Where-Object Status -eq 'FAIL').Count

Write-Host ""
Write-Host "===================== SUMMARY =====================" -ForegroundColor Cyan
Write-Host ("PASS   : {0}" -f $pass)  -ForegroundColor Green
Write-Host ("EMPTY  : {0}" -f $empty) -ForegroundColor Yellow
Write-Host ("FAIL   : {0}" -f $fail)  -ForegroundColor Red
Write-Host ("CSV    : {0}" -f $CsvPath)
if ($fail -gt 0) {
    Write-Host ("ERRORS : {0}" -f $ErrPath) -ForegroundColor Red
}
