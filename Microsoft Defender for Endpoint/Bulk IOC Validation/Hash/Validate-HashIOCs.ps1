# ============================================================================
# Disclaimer:
# The sample scripts are not supported under any Microsoft standard support
# program or service. The sample scripts are provided AS IS without warranty
# of any kind. Microsoft further disclaims all implied warranties including,
# without limitation, any implied warranties of merchantability or of fitness
# for a particular purpose. The entire risk arising out of the use or
# performance of the sample scripts and documentation remains with you. In no
# event shall Microsoft, its authors, or anyone else involved in the creation,
# production, or delivery of the scripts be liable for any damages whatsoever
# (including, without limitation, damages for loss of business profits,
# business interruption, loss of business information, or other pecuniary
# loss) arising out of the use of or inability to use the sample scripts or
# documentation, even if Microsoft has been advised of the possibility of
# such damages.
# ============================================================================

# ===================================================================
# Validate-HashIOCs.ps1
# Scan file-hash IOCs (SHA256 / SHA1 / MD5) against VirusTotal v3.
# Surfaces the Microsoft (MDAV) engine verdict: category, threat name
# (signature/result), engine version, engine update date, and detection
# method - plus the overall vendor consensus. Use to decide which custom
# MDE hash indicators MDAV already covers and can be removed.
#
# Note: VirusTotal does NOT expose the MDAV definitions/SecurityIntelligence
# version number (e.g. 1.405.x.x). To verify the sig version on an endpoint:
#   Get-MpComputerStatus | Select AntivirusSignatureVersion, AntivirusSignatureLastUpdated
#
# How to use
#   1. Export the hash IOCs from MDE (Indicators page -> Export).
#   2. Drop the .csv (or .xlsx) into this folder.
#   3. From this folder run:
#         .\Validate-HashIOCs.ps1
#      You will be prompted for your VirusTotal API key.
#   4. Open Hash-Validated.xlsx (auto-opens when finished).
# ===================================================================

[CmdletBinding()]
param(
    # Defaults: first hash-ish file in the script folder, output next to it.
    [string]$InputPath,
    [string]$OutputPath,
    [string]$VtApiKey = $env:VT_API_KEY,
    [int]$VtDelayMs   = 0    # paid VT key: 0; free tier: set to 16000 (=4 req/min)
)

$ErrorActionPreference = 'Stop'

# ---------- defaults ----------
if (-not $InputPath) {
    $candidate = Get-ChildItem -Path $PSScriptRoot -File |
        Where-Object { $_.Extension -in '.csv','.xlsx' -and $_.Name -notmatch 'Validated' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $candidate) { throw "No .csv / .xlsx input found in $PSScriptRoot. Drop your MDE hash export here." }
    $InputPath = $candidate.FullName
    Write-Host "Using input: $InputPath" -ForegroundColor Cyan
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot 'Hash-Validated.xlsx'
}

# ---------- prompt for VT key ----------
if (-not $VtApiKey) {
    $sec = Read-Host "Enter your VirusTotal API key" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        # PtrToStringUni is reliable on PS7; PtrToStringAuto can return mangled bytes.
        $VtApiKey = [Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}
# Strip whitespace and control chars - pasted keys often have stray spaces/newlines/quotes
# that VT silently rejects as HTTP 400.
if ($VtApiKey) { $VtApiKey = ($VtApiKey -replace '[\s"'']', '').Trim() }
if (-not $VtApiKey) { throw "VirusTotal API key is required." }
if ($VtApiKey.Length -lt 30) {
    Write-Warning "API key looks short ($($VtApiKey.Length) chars). VT v3 keys are 64 hex chars. Continuing anyway."
}

# ---------- modules ----------
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

# ---------- helpers ----------
function Get-HashType {
    param([string]$Value)
    $v = ($Value ?? '').Trim()
    if ($v -match '^[a-fA-F0-9]{64}$') { return 'FileSha256' }
    if ($v -match '^[a-fA-F0-9]{40}$') { return 'FileSha1'   }
    if ($v -match '^[a-fA-F0-9]{32}$') { return 'FileMd5'    }
    return 'Unknown'
}

function Get-VtFileVerdict {
    param([string]$Hash,[string]$ApiKey)
    $out = [ordered]@{
        VtStatus            = ''
        VtMalicious         = ''
        VtSuspicious        = ''
        VtHarmless          = ''
        VtUndetected        = ''
        VtReputation        = ''
        VtLastAnalysis      = ''
        # Microsoft AV engine inside VT == MDAV's published verdict.
        # VT does NOT expose the MDAV definitions/SecurityIntelligence version (1.x.x.x);
        # only the scan-engine version + the date VT last refreshed the MDAV scanner.
        MdavCategory        = ''   # malicious / harmless / undetected / type-unsupported
        MdavSignature       = ''   # threat name, e.g. Trojan:Win32/Wacatac.B!ml
        MdavEngineName      = ''   # "Microsoft"
        MdavEngineVersion   = ''   # scan engine build, e.g. 1.1.24010.10
        MdavEngineUpdateDate= ''   # YYYYMMDD - when VT last refreshed the MDAV scanner
        MdavMethod          = ''   # blacklist / signature / etc.
        VtLink              = "https://www.virustotal.com/gui/file/$Hash"
    }
    try {
        $r = Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/files/$Hash" `
            -Headers @{ 'x-apikey' = $ApiKey }
        $a = $r.data.attributes
        $s = $a.last_analysis_stats
        $out.VtStatus     = 'Success'
        $out.VtMalicious  = $s.malicious
        $out.VtSuspicious = $s.suspicious
        $out.VtHarmless   = $s.harmless
        $out.VtUndetected = $s.undetected
        $out.VtReputation = $a.reputation
        if ($a.last_analysis_date) {
            $out.VtLastAnalysis = ([DateTimeOffset]::FromUnixTimeSeconds([int64]$a.last_analysis_date)).UtcDateTime
        }
        $ms = $a.last_analysis_results.Microsoft
        if ($ms) {
            $out.MdavCategory         = $ms.category
            $out.MdavSignature        = $ms.result
            $out.MdavEngineName       = $ms.engine_name
            $out.MdavEngineVersion    = $ms.engine_version
            $out.MdavEngineUpdateDate = $ms.engine_update
            $out.MdavMethod           = $ms.method
        } else {
            $out.MdavCategory = 'not-reported'
        }
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        if     ($code -eq 404) { $out.VtStatus = 'NotFound (hash unknown to VT)' }
        elseif ($code -eq 429) { $out.VtStatus = 'RateLimited (slow down or use paid key)' }
        elseif ($code -eq 401) { $out.VtStatus = 'Unauthorized (bad API key)' }
        else                   { $out.VtStatus = "Error: $($_.Exception.Message)" }
    }
    [pscustomobject]$out
}

# ---------- input ----------
if (-not (Test-Path $InputPath)) { throw "Input file not found: $InputPath" }
$rows = if ([IO.Path]::GetExtension($InputPath) -eq '.csv') {
    Import-Csv -Path $InputPath
} else {
    Import-Excel -Path $InputPath
}
if (-not $rows) { throw "No rows found in $InputPath" }
Write-Host "Loaded $($rows.Count) rows from $InputPath" -ForegroundColor Green

# ---------- main loop ----------
$results = New-Object System.Collections.Generic.List[object]
$i = 0
foreach ($row in $rows) {
    $i++
    $props = $row.PSObject.Properties.Name
    $value = $null
    foreach ($n in 'Indicator Value','IndicatorValue','Value','Hash','Indicator','Sha256','SHA-256','SHA1','MD5') {
        if ($props -contains $n -and $row.$n) { $value = "$($row.$n)".Trim(); break }
    }
    if (-not $value) { continue }

    $type = $null
    foreach ($n in 'Indicator Type','IndicatorType','Type') {
        if ($props -contains $n -and $row.$n) { $type = "$($row.$n)".Trim(); break }
    }
    if (-not $type) { $type = Get-HashType $value }
    if ($type -notin @('FileSha256','FileSha1','FileMd5')) {
        Write-Warning "[$i/$($rows.Count)] Skipping non-hash value: $value ($type)"
        continue
    }

    Write-Host ("[{0}/{1}] {2} {3}" -f $i,$rows.Count,$type,$value) -ForegroundColor Cyan

    $base = [ordered]@{ IndicatorValue = $value; IndicatorType = $type }
    $vt = Get-VtFileVerdict -Hash $value -ApiKey $VtApiKey
    foreach ($p in $vt.PSObject.Properties) { $base[$p.Name] = $p.Value }
    if ($VtDelayMs -gt 0) { Start-Sleep -Milliseconds $VtDelayMs }

    $verdict = 'Unknown'
    if     ($base.MdavCategory -eq 'malicious')         { $verdict = 'MDAV-Malicious' }
    elseif ($base.MdavCategory -eq 'suspicious')        { $verdict = 'MDAV-Suspicious' }
    elseif ([int]($base.VtMalicious  ?? 0) -ge 1)       { $verdict = "VT-Malicious($($base.VtMalicious))" }
    elseif ([int]($base.VtSuspicious ?? 0) -ge 1)       { $verdict = "VT-Suspicious($($base.VtSuspicious))" }
    elseif ($base.MdavCategory -in @('harmless','undetected')) { $verdict = 'Clean' }
    $base['OverallVerdict'] = $verdict

    switch -Wildcard ($verdict) {
        'MDAV-Mal*'      { Write-Host "  $verdict  -> $($base.MdavSignature)" -ForegroundColor Red }
        'MDAV-Susp*'     { Write-Host "  $verdict  -> $($base.MdavSignature)" -ForegroundColor Yellow }
        'VT-Malicious*'  { Write-Host "  $verdict" -ForegroundColor Red }
        'VT-Suspicious*' { Write-Host "  $verdict" -ForegroundColor Yellow }
        'Clean'          { Write-Host "  Clean" -ForegroundColor Green }
        default          { Write-Host "  $verdict" -ForegroundColor Gray }
    }

    $results.Add([pscustomobject]$base)
}

# ---------- output ----------
Write-Host "`nWriting $OutputPath ..." -ForegroundColor Cyan
if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }

$summary = $results | Group-Object OverallVerdict | Sort-Object Count -Descending |
    Select-Object @{n='OverallVerdict';e={$_.Name}}, Count
# Hits = anything MDAV / VT already classifies (= candidates to remove from custom MDE TI)
$hits = $results | Where-Object {
    $_.OverallVerdict -like 'MDAV-*' -or $_.OverallVerdict -like 'VT-*'
}

$summary | Export-Excel -Path $OutputPath -WorksheetName 'Summary'                  -AutoSize -BoldTopRow -FreezeTopRow
$hits    | Export-Excel -Path $OutputPath -WorksheetName 'Already Covered by MDAV/VT' -AutoSize -BoldTopRow -FreezeTopRow -AutoFilter
$results | Export-Excel -Path $OutputPath -WorksheetName 'All Hashes'                -AutoSize -BoldTopRow -FreezeTopRow -AutoFilter

Write-Host "`nSummary:" -ForegroundColor Cyan
$summary | Format-Table -AutoSize
Write-Host "Done. Report: $OutputPath" -ForegroundColor Green
Start-Process $OutputPath
