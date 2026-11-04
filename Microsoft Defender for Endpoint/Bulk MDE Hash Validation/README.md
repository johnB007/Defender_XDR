# Bulk MDE Hash Validation

Review a CSV of file hash indicators using Microsoft Defender for Endpoint file
intelligence. Choose the script for Commercial, GCC High (GCCH), or DoD.

These scripts query existing Microsoft file records. They do not call VirusTotal,
submit samples, download malware, change indicators, or run endpoint response
actions. Run them on an approved workstation or automation host, not in MDE API
Explorer or Live Response.

## Choose the correct environment

| Environment | Script | Defender portal | File API base | Az.Accounts environment |
|---|---|---|---|---|
| Commercial | [Validate-HashIOCs-Commercial.ps1](./Validate-HashIOCs-Commercial.ps1) | `https://security.microsoft.com` | `https://api.security.microsoft.com` | `AzureCloud` |
| GCC High | [Validate-HashIOCs-GCCH.ps1](./Validate-HashIOCs-GCCH.ps1) | `https://security.microsoft.us` | `https://api-gov.securitycenter.microsoft.us` | `AzureUSGovernment` |
| DoD | [Validate-HashIOCs-DoD.ps1](./Validate-HashIOCs-DoD.ps1) | `https://security.apps.mil` | `https://api-gov.securitycenter.microsoft.us` | `AzureUSGovernment` |

GCC High and DoD share the documented MDE API hostname. The account and explicitly
supplied tenant determine the target. Neither script discovers or changes your
tenant automatically. GCC is a different offering and is not covered by the
GCCH script.

Commercial requests use `https://api.securitycenter.microsoft.com` as the token
resource while calling the file API at `https://api.security.microsoft.com`.
Government requests use `https://api-gov.securitycenter.microsoft.us` for both.

## Prerequisites

1. PowerShell 7 or later. Windows PowerShell 5.1 is not supported.
2. `Az.Accounts` version 3 or later, installed through an approved package source
   or software distribution process.
3. Approved MDE `File.Read.All` delegated access and the required user role
   permissions, including View Data. Azure subscription permissions alone are
   insufficient.
4. An approved execution host, input location, and output location for the
   selected environment.
5. HTTPS access to the selected MDE API and the environment's identity endpoints.
   The scripts are not offline tools.

Check your PowerShell and module:

```powershell
$PSVersionTable.PSVersion
Get-Module -ListAvailable Az.Accounts
```

If the module is missing, have it installed from a source approved for that host.
Do not copy a corporate laptop's package proxy or repository settings into a
government environment. The scripts do not install modules or change repository
registrations.

No Excel installation, ImportExcel module, VirusTotal account, or VirusTotal API
key is required. Signing into a browser does not authenticate PowerShell.
Successful access in API Explorer also does not establish that the Az.Accounts
client has the necessary MDE consent or permissions.

## Prepare the CSV

Keep the header row. Use one complete hash per row.

| Column | Requirement |
|---|---|
| `Indicator Value` | Required. SHA1 or SHA256. |
| `Indicator Type` | Optional. Use `FileSha1` or `FileSha256`, consistent with the value. |

The scripts also recognize `IndicatorValue`, `Hash`, `Value`, `Indicator`,
`Sha256`, `SHA-256`, `SHA1`, and `MD5` as value headers, and `IndicatorType` or
`Type` as type headers. Matching is case insensitive.

Synthetic input example:

```csv
Indicator Value,Indicator Type
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,FileSha256
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,FileSha1
```

These repeated character values illustrate the format only. They are not test
files or claims about real malware. MD5, invalid hashes, and conflicting declared
types are recorded without sending a lookup. Extra input columns are not sent to
the file API or copied into the report. Keep an unchanged original export if its
metadata is needed later.

Save only the script for your environment beside the CSV, or download the
corresponding PS1 linked above. The complete scripts appear below.

## Commercial

### Authenticate and run Commercial

In PowerShell 7, change to the approved folder containing the script and CSV.
Run the following in the same window, substituting your CSV filename:

```powershell
Import-Module Az.Accounts -MinimumVersion 3.0.0
$tenantId = Read-Host 'Enter the approved Commercial tenant ID'
Connect-AzAccount -Environment AzureCloud -Tenant $tenantId -Scope Process -SkipContextPopulation
.\Validate-HashIOCs-Commercial.ps1 -InputPath '.\CustomTiIndicators.20261104.csv' -TenantId $tenantId
```

Review the sign in prompt and use the approved Commercial identity. The script
refuses a government context or a different tenant.

Default report: `CustomTiIndicators.20261104.MDE-Commercial-Validated.csv`.

### Complete Commercial script

Save as `Validate-HashIOCs-Commercial.ps1`:

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Look up hash indicators through the Commercial MDE file information API.
.DESCRIPTION
    Run on an approved workstation, not in MDE Live Response. Requires an existing
    Az.Accounts AzureCloud context with File.Read.All access. Does not sign
    in, change contexts, call VirusTotal, submit samples, or modify indicators.
    Saves each result immediately. Resume requires the same input file and tenant.
.PARAMETER TenantId
    The Commercial tenant to verify against the existing Az.Accounts context.
.PARAMETER Resume
    Continue an existing report. Recorded rows, including failures, are skipped.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,
    [Parameter(Mandatory)]
    [guid]$TenantId,
    [string]$OutputPath,
    [switch]$Resume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$apiBase = 'https://api.security.microsoft.com'
$tokenResource = 'https://api.securitycenter.microsoft.com'
$requestIntervalMs = 2500
$maxRetries = 5
$accessToken = $null
$tokenExpiry = [datetimeoffset]::MinValue
$requestClock = [Diagnostics.Stopwatch]::StartNew()
$lastRequestMs = -$requestIntervalMs

function Get-Field {
    param([object]$Object, [string[]]$Names)
    foreach ($name in $Names) {
        if ($null -ne $Object) {
            $property = $Object.PSObject.Properties[$name]
            if ($null -ne $property -and $null -ne $property.Value -and "$($property.Value)" -ne '') {
                return $property.Value
            }
        }
    }
    return $null
}

function Assert-MdeContext {
    $context = Get-AzContext -ErrorAction Stop
    if ($null -eq $context -or $null -eq $context.Tenant -or $null -eq $context.Environment) {
        throw 'No authenticated Az.Accounts context. Sign in to the approved Commercial tenant first.'
    }
    if ($context.Environment.Name -ne 'AzureCloud' -or
        $context.Tenant.Id -ne $TenantId.ToString()) {
        throw 'The current context is not AzureCloud in the requested tenant. No lookup is allowed.'
    }
}

function Get-MdeAccessToken {
    Assert-MdeContext
    if ($null -eq $script:accessToken -or $script:tokenExpiry -le [datetimeoffset]::UtcNow.AddMinutes(5)) {
        $token = Get-AzAccessToken -ResourceUrl $tokenResource -TenantId $TenantId.ToString() -AsSecureString -ErrorAction Stop
        if ($token.Token -isnot [securestring]) { throw 'Authentication did not return a secure MDE access token.' }
        $script:accessToken = $token.Token
        $script:tokenExpiry = [datetimeoffset]$token.ExpiresOn
        if ($script:tokenExpiry -le [datetimeoffset]::UtcNow) { throw 'The MDE access token has expired.' }
    }
}

function Wait-RequestSlot {
    $remaining = $requestIntervalMs - ($requestClock.ElapsedMilliseconds - $script:lastRequestMs)
    if ($remaining -gt 0) { Start-Sleep -Milliseconds ([int][math]::Ceiling($remaining)) }
    $script:lastRequestMs = $requestClock.ElapsedMilliseconds
}

function Get-RetryDelay {
    param([object]$Headers, [int]$Attempt)
    $delay = [math]::Min(60, [math]::Pow(2, $Attempt + 1))
    if ($null -ne $Headers -and $Headers.ContainsKey('Retry-After')) {
        $value = [string](@($Headers['Retry-After'])[0])
        $seconds = 0
        $date = [datetimeoffset]::MinValue
        if ([int]::TryParse($value, [ref]$seconds)) {
            $delay = [math]::Max($delay, $seconds)
        } elseif ([datetimeoffset]::TryParse($value, [ref]$date)) {
            $delay = [math]::Max($delay, [math]::Ceiling(($date - [datetimeoffset]::UtcNow).TotalSeconds))
        }
    }
    return $delay
}

function Get-MdeFile {
    param([string]$Hash)
    $authRetried = $false
    for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
        Get-MdeAccessToken
        Wait-RequestSlot
        $httpStatus = 0
        $responseHeaders = $null
        try {
            $response = Invoke-RestMethod -Method Get -Uri "$apiBase/api/files/$Hash" `
                -Authentication Bearer -Token $accessToken -MaximumRedirection 0 `
                -TimeoutSec 60 -SkipHttpErrorCheck -StatusCodeVariable httpStatus `
                -ResponseHeadersVariable responseHeaders -ErrorAction Stop
        } catch {
            if ($attempt -eq $maxRetries) {
                return @{ Status = 'RequestFailed'; HttpStatus = $httpStatus; File = $null
                    Error = 'Transport failure after bounded retries. Check connectivity and proxy policy.' }
            }
            Write-Warning "Transport failure. Retrying request ($($attempt + 1)/$maxRetries)."
            Start-Sleep -Seconds (Get-RetryDelay -Headers $null -Attempt $attempt)
            continue
        }
        if ($httpStatus -eq 200) {
            $returnedHash = if ($Hash.Length -eq 40) {
                Get-Field $response @('sha1')
            } else {
                Get-Field $response @('sha256')
            }
            if ($returnedHash -ne $Hash) {
                return @{ Status = 'ResponseMismatch'; HttpStatus = 200; File = $null
                    Error = 'The API did not return the requested hash. Stop and investigate.' }
            }
            return @{ Status = 'Found'; HttpStatus = 200; File = $response; Error = '' }
        }
        if ($httpStatus -eq 404) {
            return @{ Status = 'NotFound'; HttpStatus = 404; File = $null
                Error = 'No file record. This is not a clean verdict.' }
        }
        if ($httpStatus -eq 401 -and -not $authRetried -and $attempt -lt $maxRetries) {
            $script:accessToken = $null
            $authRetried = $true
            Write-Warning 'The API rejected the token. Refreshing once.'
            continue
        }
        if (($httpStatus -eq 429 -or $httpStatus -ge 500) -and $attempt -lt $maxRetries) {
            $delay = Get-RetryDelay -Headers $responseHeaders -Attempt $attempt
            Write-Warning "API returned HTTP $httpStatus. Retrying after $delay seconds."
            Start-Sleep -Seconds $delay
            continue
        }
        $status = switch ($httpStatus) {
            401 { 'Unauthorized' }
            403 { 'Forbidden' }
            429 { 'RateLimited' }
            default { 'RequestFailed' }
        }
        return @{ Status = $status; HttpStatus = $httpStatus; File = $null
            Error = "API returned HTTP $httpStatus. No verdict is available." }
    }
}

$inputFile = Get-Item -LiteralPath $InputPath -ErrorAction Stop
if ($inputFile.PSIsContainer -or $inputFile.Extension -ne '.csv') { throw 'Input must be a CSV file.' }
$inputDigest = (Get-FileHash -LiteralPath $inputFile.FullName -Algorithm SHA256).Hash
$rows = @(Import-Csv -LiteralPath $inputFile.FullName)
if ($rows.Count -eq 0) { throw 'The input CSV has no data rows.' }
$valueNames = @('Indicator Value', 'IndicatorValue', 'Value', 'Hash', 'Indicator', 'Sha256', 'SHA-256', 'SHA1', 'MD5')
if (-not @($rows[0].PSObject.Properties.Name | Where-Object { $_ -in $valueNames }).Count) {
    throw 'No hash column found. Use Indicator Value as the CSV header.'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $inputFile.DirectoryName "$($inputFile.BaseName).MDE-Commercial-Validated.csv"
}
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ($OutputPath -eq $inputFile.FullName) { throw 'Output must not overwrite the input CSV.' }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $OutputPath) -PathType Container)) {
    throw 'The output directory must already exist in approved storage.'
}
$completed = [Collections.Generic.HashSet[int]]::new()
$failureStatuses = @('RequestFailed', 'Unauthorized', 'Forbidden', 'RateLimited', 'ResponseMismatch')
$hadFailures = $false
$columns = @('InputRow', 'InputFileSha256', 'TenantId', 'ApiBaseUri', 'IndicatorValue', 'IndicatorType',
    'LookupStatus', 'HttpStatus', 'DeterminationType', 'ThreatName', 'GlobalPrevalence',
    'GlobalFirstObserved', 'GlobalLastObserved', 'Size', 'IsPeFile', 'Signer',
    'IsValidCertificate', 'Error', 'QueriedAtUtc')
if (Test-Path -LiteralPath $OutputPath) {
    if (-not $Resume) { throw 'Output already exists. Use Resume or choose a new OutputPath.' }
    $previous = @(Import-Csv -LiteralPath $OutputPath)
    if ($previous.Count -eq 0 -or ($previous[0].PSObject.Properties.Name -join ',') -ne ($columns -join ',')) {
        throw 'The resume report is empty or has an invalid schema.'
    }
    foreach ($entry in $previous) {
        $rowNumber = 0
        if ($entry.InputFileSha256 -ne $inputDigest -or $entry.TenantId -ne $TenantId.ToString() -or
            $entry.ApiBaseUri -ne $apiBase -or -not [int]::TryParse($entry.InputRow, [ref]$rowNumber) -or
            $rowNumber -lt 1 -or $rowNumber -gt $rows.Count -or -not $completed.Add($rowNumber)) {
            throw 'The resume report does not match this input and tenant, or contains duplicate or invalid rows.'
        }
        if ($entry.LookupStatus -notin @('Found', 'NotFound', 'Unsupported', 'InvalidInput') + $failureStatuses) {
            throw 'The resume report contains an invalid lookup status.'
        }
        if ($entry.LookupStatus -in $failureStatuses -or $entry.LookupStatus -in @('InvalidInput', 'Unsupported')) {
            $hadFailures = $true
        }
    }
} elseif ($Resume) {
    throw 'Resume requires an existing report.'
}

Import-Module Az.Accounts -MinimumVersion 3.0.0 -ErrorAction Stop
Assert-MdeContext
Write-Output "Rows: $($rows.Count). Already recorded: $($completed.Count). Report: $OutputPath"
Write-Output 'Only the Commercial MDE file API is used. No indicators are modified.'
try {
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $rowNumber = $index + 1
        if ($completed.Contains($rowNumber)) { continue }
        $row = $rows[$index]
        $hash = ([string](Get-Field $row $valueNames)).Trim().ToLowerInvariant()
        $declaredType = ([string](Get-Field $row @('Indicator Type', 'IndicatorType', 'Type'))).Trim()
        $type = switch -Regex ($hash) {
            '^[a-f0-9]{64}$' { 'FileSha256'; break }
            '^[a-f0-9]{40}$' { 'FileSha1'; break }
            '^[a-f0-9]{32}$' { 'FileMd5'; break }
            default { 'Unknown' }
        }
        if ($type -eq 'Unknown' -or ($declaredType -and $declaredType -ne $type)) {
            $lookup = @{ Status = 'InvalidInput'; HttpStatus = ''; File = $null
                Error = 'Invalid hash or a declared type that does not match its length. No request sent.' }
        } elseif ($type -eq 'FileMd5') {
            $lookup = @{ Status = 'Unsupported'; HttpStatus = ''; File = $null
                Error = 'This API accepts SHA1 or SHA256, not MD5. No request sent.' }
        } else {
            $lookup = Get-MdeFile -Hash $hash
        }
        $file = $lookup.File
        $record = [pscustomobject][ordered]@{
            InputRow = $rowNumber
            InputFileSha256 = $inputDigest
            TenantId = $TenantId.ToString()
            ApiBaseUri = $apiBase
            IndicatorValue = if ($type -ne 'Unknown') { $hash } else { '' }
            IndicatorType = $type
            LookupStatus = $lookup.Status
            HttpStatus = $lookup.HttpStatus
            DeterminationType = Get-Field $file @('determinationType')
            ThreatName = Get-Field $file @('determinationValue')
            GlobalPrevalence = Get-Field $file @('globalPrevalence')
            GlobalFirstObserved = Get-Field $file @('globalFirstObserved')
            GlobalLastObserved = Get-Field $file @('globalLastObserved')
            Size = Get-Field $file @('size')
            IsPeFile = Get-Field $file @('isPeFile')
            Signer = Get-Field $file @('signer')
            IsValidCertificate = Get-Field $file @('isValidCertificate')
            Error = $lookup.Error
            QueriedAtUtc = [datetimeoffset]::UtcNow.ToString('o')
        }
        foreach ($property in $record.PSObject.Properties) {
            if ($property.Value -is [string] -and $property.Value -match '^\s*[=+@\-]') {
                $property.Value = "'" + $property.Value
            }
        }
        $record | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8 -Append
        Write-Output "[$rowNumber/$($rows.Count)] $type : $($lookup.Status)"
        if ($lookup.Status -in $failureStatuses -or $lookup.Status -in @('InvalidInput', 'Unsupported')) {
            $hadFailures = $true
            Write-Warning "Row $rowNumber : $($lookup.Error)"
        }
        if ($lookup.Status -in @('Unauthorized', 'Forbidden', 'ResponseMismatch')) {
            throw "Stopped on $($lookup.Status). Completed rows are saved in $OutputPath."
        }
    }
} finally {
    $accessToken = $null
    $requestClock.Stop()
}
Write-Output "Saved: $OutputPath"
if ($hadFailures) {
    throw 'The report contains failed, invalid, or unsupported rows. Review LookupStatus and Error. Recorded rows are skipped on resume.'
}
```

## GCC High

### Authenticate and run GCC High

Use the approved GCC High host and storage. In PowerShell 7, run:

```powershell
Import-Module Az.Accounts -MinimumVersion 3.0.0
$tenantId = Read-Host 'Enter the approved GCC High tenant ID'
Connect-AzAccount -Environment AzureUSGovernment -Tenant $tenantId -Scope Process -SkipContextPopulation
.\Validate-HashIOCs-GCCH.ps1 -InputPath '.\CustomTiIndicators.20261104.csv' -TenantId $tenantId
```

Use the approved government identity. The script refuses a Commercial context or
a different tenant. The government API hostname alone cannot distinguish a GCC
High tenant from a DoD tenant; verify the tenant ID before signing in.

Default report: `CustomTiIndicators.20261104.MDE-GCCH-Validated.csv`.

### Complete GCC High script

Save as `Validate-HashIOCs-GCCH.ps1`:

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Look up hash indicators through the GCC High MDE file information API.
.DESCRIPTION
    Run on an approved workstation, not in MDE Live Response. Requires an existing
    Az.Accounts AzureUSGovernment context with File.Read.All access. Does not sign
    in, change contexts, call VirusTotal, submit samples, or modify indicators.
    Saves each result immediately. Resume requires the same input file and tenant.
.PARAMETER TenantId
    The GCC High tenant to verify against the existing Az.Accounts context.
.PARAMETER Resume
    Continue an existing report. Recorded rows, including failures, are skipped.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,
    [Parameter(Mandatory)]
    [guid]$TenantId,
    [string]$OutputPath,
    [switch]$Resume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$apiBase = 'https://api-gov.securitycenter.microsoft.us'
$tokenResource = 'https://api-gov.securitycenter.microsoft.us'
$requestIntervalMs = 2500
$maxRetries = 5
$accessToken = $null
$tokenExpiry = [datetimeoffset]::MinValue
$requestClock = [Diagnostics.Stopwatch]::StartNew()
$lastRequestMs = -$requestIntervalMs

function Get-Field {
    param([object]$Object, [string[]]$Names)
    foreach ($name in $Names) {
        if ($null -ne $Object) {
            $property = $Object.PSObject.Properties[$name]
            if ($null -ne $property -and $null -ne $property.Value -and "$($property.Value)" -ne '') {
                return $property.Value
            }
        }
    }
    return $null
}

function Assert-MdeContext {
    $context = Get-AzContext -ErrorAction Stop
    if ($null -eq $context -or $null -eq $context.Tenant -or $null -eq $context.Environment) {
        throw 'No authenticated Az.Accounts context. Sign in to the approved GCC High tenant first.'
    }
    if ($context.Environment.Name -ne 'AzureUSGovernment' -or
        $context.Tenant.Id -ne $TenantId.ToString()) {
        throw 'The current context is not AzureUSGovernment in the requested tenant. No lookup is allowed.'
    }
}

function Get-MdeAccessToken {
    Assert-MdeContext
    if ($null -eq $script:accessToken -or $script:tokenExpiry -le [datetimeoffset]::UtcNow.AddMinutes(5)) {
        $token = Get-AzAccessToken -ResourceUrl $tokenResource -TenantId $TenantId.ToString() -AsSecureString -ErrorAction Stop
        if ($token.Token -isnot [securestring]) { throw 'Authentication did not return a secure MDE access token.' }
        $script:accessToken = $token.Token
        $script:tokenExpiry = [datetimeoffset]$token.ExpiresOn
        if ($script:tokenExpiry -le [datetimeoffset]::UtcNow) { throw 'The MDE access token has expired.' }
    }
}

function Wait-RequestSlot {
    $remaining = $requestIntervalMs - ($requestClock.ElapsedMilliseconds - $script:lastRequestMs)
    if ($remaining -gt 0) { Start-Sleep -Milliseconds ([int][math]::Ceiling($remaining)) }
    $script:lastRequestMs = $requestClock.ElapsedMilliseconds
}

function Get-RetryDelay {
    param([object]$Headers, [int]$Attempt)
    $delay = [math]::Min(60, [math]::Pow(2, $Attempt + 1))
    if ($null -ne $Headers -and $Headers.ContainsKey('Retry-After')) {
        $value = [string](@($Headers['Retry-After'])[0])
        $seconds = 0
        $date = [datetimeoffset]::MinValue
        if ([int]::TryParse($value, [ref]$seconds)) {
            $delay = [math]::Max($delay, $seconds)
        } elseif ([datetimeoffset]::TryParse($value, [ref]$date)) {
            $delay = [math]::Max($delay, [math]::Ceiling(($date - [datetimeoffset]::UtcNow).TotalSeconds))
        }
    }
    return $delay
}

function Get-MdeFile {
    param([string]$Hash)
    $authRetried = $false
    for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
        Get-MdeAccessToken
        Wait-RequestSlot
        $httpStatus = 0
        $responseHeaders = $null
        try {
            $response = Invoke-RestMethod -Method Get -Uri "$apiBase/api/files/$Hash" `
                -Authentication Bearer -Token $accessToken -MaximumRedirection 0 `
                -TimeoutSec 60 -SkipHttpErrorCheck -StatusCodeVariable httpStatus `
                -ResponseHeadersVariable responseHeaders -ErrorAction Stop
        } catch {
            if ($attempt -eq $maxRetries) {
                return @{ Status = 'RequestFailed'; HttpStatus = $httpStatus; File = $null
                    Error = 'Transport failure after bounded retries. Check connectivity and proxy policy.' }
            }
            Write-Warning "Transport failure. Retrying request ($($attempt + 1)/$maxRetries)."
            Start-Sleep -Seconds (Get-RetryDelay -Headers $null -Attempt $attempt)
            continue
        }
        if ($httpStatus -eq 200) {
            $returnedHash = if ($Hash.Length -eq 40) {
                Get-Field $response @('sha1')
            } else {
                Get-Field $response @('sha256')
            }
            if ($returnedHash -ne $Hash) {
                return @{ Status = 'ResponseMismatch'; HttpStatus = 200; File = $null
                    Error = 'The API did not return the requested hash. Stop and investigate.' }
            }
            return @{ Status = 'Found'; HttpStatus = 200; File = $response; Error = '' }
        }
        if ($httpStatus -eq 404) {
            return @{ Status = 'NotFound'; HttpStatus = 404; File = $null
                Error = 'No file record. This is not a clean verdict.' }
        }
        if ($httpStatus -eq 401 -and -not $authRetried -and $attempt -lt $maxRetries) {
            $script:accessToken = $null
            $authRetried = $true
            Write-Warning 'The API rejected the token. Refreshing once.'
            continue
        }
        if (($httpStatus -eq 429 -or $httpStatus -ge 500) -and $attempt -lt $maxRetries) {
            $delay = Get-RetryDelay -Headers $responseHeaders -Attempt $attempt
            Write-Warning "API returned HTTP $httpStatus. Retrying after $delay seconds."
            Start-Sleep -Seconds $delay
            continue
        }
        $status = switch ($httpStatus) {
            401 { 'Unauthorized' }
            403 { 'Forbidden' }
            429 { 'RateLimited' }
            default { 'RequestFailed' }
        }
        return @{ Status = $status; HttpStatus = $httpStatus; File = $null
            Error = "API returned HTTP $httpStatus. No verdict is available." }
    }
}

$inputFile = Get-Item -LiteralPath $InputPath -ErrorAction Stop
if ($inputFile.PSIsContainer -or $inputFile.Extension -ne '.csv') { throw 'Input must be a CSV file.' }
$inputDigest = (Get-FileHash -LiteralPath $inputFile.FullName -Algorithm SHA256).Hash
$rows = @(Import-Csv -LiteralPath $inputFile.FullName)
if ($rows.Count -eq 0) { throw 'The input CSV has no data rows.' }
$valueNames = @('Indicator Value', 'IndicatorValue', 'Value', 'Hash', 'Indicator', 'Sha256', 'SHA-256', 'SHA1', 'MD5')
if (-not @($rows[0].PSObject.Properties.Name | Where-Object { $_ -in $valueNames }).Count) {
    throw 'No hash column found. Use Indicator Value as the CSV header.'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $inputFile.DirectoryName "$($inputFile.BaseName).MDE-GCCH-Validated.csv"
}
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ($OutputPath -eq $inputFile.FullName) { throw 'Output must not overwrite the input CSV.' }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $OutputPath) -PathType Container)) {
    throw 'The output directory must already exist in approved storage.'
}
$completed = [Collections.Generic.HashSet[int]]::new()
$failureStatuses = @('RequestFailed', 'Unauthorized', 'Forbidden', 'RateLimited', 'ResponseMismatch')
$hadFailures = $false
$columns = @('InputRow', 'InputFileSha256', 'TenantId', 'ApiBaseUri', 'IndicatorValue', 'IndicatorType',
    'LookupStatus', 'HttpStatus', 'DeterminationType', 'ThreatName', 'GlobalPrevalence',
    'GlobalFirstObserved', 'GlobalLastObserved', 'Size', 'IsPeFile', 'Signer',
    'IsValidCertificate', 'Error', 'QueriedAtUtc')
if (Test-Path -LiteralPath $OutputPath) {
    if (-not $Resume) { throw 'Output already exists. Use Resume or choose a new OutputPath.' }
    $previous = @(Import-Csv -LiteralPath $OutputPath)
    if ($previous.Count -eq 0 -or ($previous[0].PSObject.Properties.Name -join ',') -ne ($columns -join ',')) {
        throw 'The resume report is empty or has an invalid schema.'
    }
    foreach ($entry in $previous) {
        $rowNumber = 0
        if ($entry.InputFileSha256 -ne $inputDigest -or $entry.TenantId -ne $TenantId.ToString() -or
            $entry.ApiBaseUri -ne $apiBase -or -not [int]::TryParse($entry.InputRow, [ref]$rowNumber) -or
            $rowNumber -lt 1 -or $rowNumber -gt $rows.Count -or -not $completed.Add($rowNumber)) {
            throw 'The resume report does not match this input and tenant, or contains duplicate or invalid rows.'
        }
        if ($entry.LookupStatus -notin @('Found', 'NotFound', 'Unsupported', 'InvalidInput') + $failureStatuses) {
            throw 'The resume report contains an invalid lookup status.'
        }
        if ($entry.LookupStatus -in $failureStatuses -or $entry.LookupStatus -in @('InvalidInput', 'Unsupported')) {
            $hadFailures = $true
        }
    }
} elseif ($Resume) {
    throw 'Resume requires an existing report.'
}

Import-Module Az.Accounts -MinimumVersion 3.0.0 -ErrorAction Stop
Assert-MdeContext
Write-Output "Rows: $($rows.Count). Already recorded: $($completed.Count). Report: $OutputPath"
Write-Output 'Only the GCC High MDE file API is used. No indicators are modified.'
try {
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $rowNumber = $index + 1
        if ($completed.Contains($rowNumber)) { continue }
        $row = $rows[$index]
        $hash = ([string](Get-Field $row $valueNames)).Trim().ToLowerInvariant()
        $declaredType = ([string](Get-Field $row @('Indicator Type', 'IndicatorType', 'Type'))).Trim()
        $type = switch -Regex ($hash) {
            '^[a-f0-9]{64}$' { 'FileSha256'; break }
            '^[a-f0-9]{40}$' { 'FileSha1'; break }
            '^[a-f0-9]{32}$' { 'FileMd5'; break }
            default { 'Unknown' }
        }
        if ($type -eq 'Unknown' -or ($declaredType -and $declaredType -ne $type)) {
            $lookup = @{ Status = 'InvalidInput'; HttpStatus = ''; File = $null
                Error = 'Invalid hash or a declared type that does not match its length. No request sent.' }
        } elseif ($type -eq 'FileMd5') {
            $lookup = @{ Status = 'Unsupported'; HttpStatus = ''; File = $null
                Error = 'This API accepts SHA1 or SHA256, not MD5. No request sent.' }
        } else {
            $lookup = Get-MdeFile -Hash $hash
        }
        $file = $lookup.File
        $record = [pscustomobject][ordered]@{
            InputRow = $rowNumber
            InputFileSha256 = $inputDigest
            TenantId = $TenantId.ToString()
            ApiBaseUri = $apiBase
            IndicatorValue = if ($type -ne 'Unknown') { $hash } else { '' }
            IndicatorType = $type
            LookupStatus = $lookup.Status
            HttpStatus = $lookup.HttpStatus
            DeterminationType = Get-Field $file @('determinationType')
            ThreatName = Get-Field $file @('determinationValue')
            GlobalPrevalence = Get-Field $file @('globalPrevalence')
            GlobalFirstObserved = Get-Field $file @('globalFirstObserved')
            GlobalLastObserved = Get-Field $file @('globalLastObserved')
            Size = Get-Field $file @('size')
            IsPeFile = Get-Field $file @('isPeFile')
            Signer = Get-Field $file @('signer')
            IsValidCertificate = Get-Field $file @('isValidCertificate')
            Error = $lookup.Error
            QueriedAtUtc = [datetimeoffset]::UtcNow.ToString('o')
        }
        foreach ($property in $record.PSObject.Properties) {
            if ($property.Value -is [string] -and $property.Value -match '^\s*[=+@\-]') {
                $property.Value = "'" + $property.Value
            }
        }
        $record | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8 -Append
        Write-Output "[$rowNumber/$($rows.Count)] $type : $($lookup.Status)"
        if ($lookup.Status -in $failureStatuses -or $lookup.Status -in @('InvalidInput', 'Unsupported')) {
            $hadFailures = $true
            Write-Warning "Row $rowNumber : $($lookup.Error)"
        }
        if ($lookup.Status -in @('Unauthorized', 'Forbidden', 'ResponseMismatch')) {
            throw "Stopped on $($lookup.Status). Completed rows are saved in $OutputPath."
        }
    }
} finally {
    $accessToken = $null
    $requestClock.Stop()
}
Write-Output "Saved: $OutputPath"
if ($hadFailures) {
    throw 'The report contains failed, invalid, or unsupported rows. Review LookupStatus and Error. Recorded rows are skipped on resume.'
}
```

## DoD

### Authenticate and run DoD

Use the approved DoD host and storage. Do not copy the CSV into Commercial
storage or query the Commercial API. In PowerShell 7, run:

```powershell
Import-Module Az.Accounts -MinimumVersion 3.0.0
$tenantId = Read-Host 'Enter the approved DoD tenant ID'
Connect-AzAccount -Environment AzureUSGovernment -Tenant $tenantId -Scope Process -SkipContextPopulation
.\Validate-HashIOCs-DoD.ps1 -InputPath '.\CustomTiIndicators.20261104.csv' -TenantId $tenantId
```

Use the approved DoD identity. The script refuses a Commercial context or a
different tenant. It does not establish IL5 compliance or authorize a transfer.
The host, storage, network, identity, and service agreement remain part of the
approved boundary.

Default report: `CustomTiIndicators.20261104.MDE-DoD-Validated.csv`.

### Complete DoD script

Save as `Validate-HashIOCs-DoD.ps1`:

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Look up hash indicators through the DoD MDE file information API.
.DESCRIPTION
    Run on an approved workstation, not in MDE Live Response. Requires an existing
    Az.Accounts AzureUSGovernment context with File.Read.All access. Does not sign
    in, change contexts, call VirusTotal, submit samples, or modify indicators.
    Saves each result immediately. Resume requires the same input file and tenant.
.PARAMETER TenantId
    The DoD tenant to verify against the existing Az.Accounts context.
.PARAMETER Resume
    Continue an existing report. Recorded rows, including failures, are skipped.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,
    [Parameter(Mandatory)]
    [guid]$TenantId,
    [string]$OutputPath,
    [switch]$Resume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$apiBase = 'https://api-gov.securitycenter.microsoft.us'
$tokenResource = 'https://api-gov.securitycenter.microsoft.us'
$requestIntervalMs = 2500
$maxRetries = 5
$accessToken = $null
$tokenExpiry = [datetimeoffset]::MinValue
$requestClock = [Diagnostics.Stopwatch]::StartNew()
$lastRequestMs = -$requestIntervalMs

function Get-Field {
    param([object]$Object, [string[]]$Names)
    foreach ($name in $Names) {
        if ($null -ne $Object) {
            $property = $Object.PSObject.Properties[$name]
            if ($null -ne $property -and $null -ne $property.Value -and "$($property.Value)" -ne '') {
                return $property.Value
            }
        }
    }
    return $null
}

function Assert-MdeContext {
    $context = Get-AzContext -ErrorAction Stop
    if ($null -eq $context -or $null -eq $context.Tenant -or $null -eq $context.Environment) {
        throw 'No authenticated Az.Accounts context. Sign in to the approved DoD tenant first.'
    }
    if ($context.Environment.Name -ne 'AzureUSGovernment' -or
        $context.Tenant.Id -ne $TenantId.ToString()) {
        throw 'The current context is not AzureUSGovernment in the requested tenant. No lookup is allowed.'
    }
}

function Get-MdeAccessToken {
    Assert-MdeContext
    if ($null -eq $script:accessToken -or $script:tokenExpiry -le [datetimeoffset]::UtcNow.AddMinutes(5)) {
        $token = Get-AzAccessToken -ResourceUrl $tokenResource -TenantId $TenantId.ToString() -AsSecureString -ErrorAction Stop
        if ($token.Token -isnot [securestring]) { throw 'Authentication did not return a secure MDE access token.' }
        $script:accessToken = $token.Token
        $script:tokenExpiry = [datetimeoffset]$token.ExpiresOn
        if ($script:tokenExpiry -le [datetimeoffset]::UtcNow) { throw 'The MDE access token has expired.' }
    }
}

function Wait-RequestSlot {
    $remaining = $requestIntervalMs - ($requestClock.ElapsedMilliseconds - $script:lastRequestMs)
    if ($remaining -gt 0) { Start-Sleep -Milliseconds ([int][math]::Ceiling($remaining)) }
    $script:lastRequestMs = $requestClock.ElapsedMilliseconds
}

function Get-RetryDelay {
    param([object]$Headers, [int]$Attempt)
    $delay = [math]::Min(60, [math]::Pow(2, $Attempt + 1))
    if ($null -ne $Headers -and $Headers.ContainsKey('Retry-After')) {
        $value = [string](@($Headers['Retry-After'])[0])
        $seconds = 0
        $date = [datetimeoffset]::MinValue
        if ([int]::TryParse($value, [ref]$seconds)) {
            $delay = [math]::Max($delay, $seconds)
        } elseif ([datetimeoffset]::TryParse($value, [ref]$date)) {
            $delay = [math]::Max($delay, [math]::Ceiling(($date - [datetimeoffset]::UtcNow).TotalSeconds))
        }
    }
    return $delay
}

function Get-MdeFile {
    param([string]$Hash)
    $authRetried = $false
    for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
        Get-MdeAccessToken
        Wait-RequestSlot
        $httpStatus = 0
        $responseHeaders = $null
        try {
            $response = Invoke-RestMethod -Method Get -Uri "$apiBase/api/files/$Hash" `
                -Authentication Bearer -Token $accessToken -MaximumRedirection 0 `
                -TimeoutSec 60 -SkipHttpErrorCheck -StatusCodeVariable httpStatus `
                -ResponseHeadersVariable responseHeaders -ErrorAction Stop
        } catch {
            if ($attempt -eq $maxRetries) {
                return @{ Status = 'RequestFailed'; HttpStatus = $httpStatus; File = $null
                    Error = 'Transport failure after bounded retries. Check connectivity and proxy policy.' }
            }
            Write-Warning "Transport failure. Retrying request ($($attempt + 1)/$maxRetries)."
            Start-Sleep -Seconds (Get-RetryDelay -Headers $null -Attempt $attempt)
            continue
        }
        if ($httpStatus -eq 200) {
            $returnedHash = if ($Hash.Length -eq 40) {
                Get-Field $response @('sha1')
            } else {
                Get-Field $response @('sha256')
            }
            if ($returnedHash -ne $Hash) {
                return @{ Status = 'ResponseMismatch'; HttpStatus = 200; File = $null
                    Error = 'The API did not return the requested hash. Stop and investigate.' }
            }
            return @{ Status = 'Found'; HttpStatus = 200; File = $response; Error = '' }
        }
        if ($httpStatus -eq 404) {
            return @{ Status = 'NotFound'; HttpStatus = 404; File = $null
                Error = 'No file record. This is not a clean verdict.' }
        }
        if ($httpStatus -eq 401 -and -not $authRetried -and $attempt -lt $maxRetries) {
            $script:accessToken = $null
            $authRetried = $true
            Write-Warning 'The API rejected the token. Refreshing once.'
            continue
        }
        if (($httpStatus -eq 429 -or $httpStatus -ge 500) -and $attempt -lt $maxRetries) {
            $delay = Get-RetryDelay -Headers $responseHeaders -Attempt $attempt
            Write-Warning "API returned HTTP $httpStatus. Retrying after $delay seconds."
            Start-Sleep -Seconds $delay
            continue
        }
        $status = switch ($httpStatus) {
            401 { 'Unauthorized' }
            403 { 'Forbidden' }
            429 { 'RateLimited' }
            default { 'RequestFailed' }
        }
        return @{ Status = $status; HttpStatus = $httpStatus; File = $null
            Error = "API returned HTTP $httpStatus. No verdict is available." }
    }
}

$inputFile = Get-Item -LiteralPath $InputPath -ErrorAction Stop
if ($inputFile.PSIsContainer -or $inputFile.Extension -ne '.csv') { throw 'Input must be a CSV file.' }
$inputDigest = (Get-FileHash -LiteralPath $inputFile.FullName -Algorithm SHA256).Hash
$rows = @(Import-Csv -LiteralPath $inputFile.FullName)
if ($rows.Count -eq 0) { throw 'The input CSV has no data rows.' }
$valueNames = @('Indicator Value', 'IndicatorValue', 'Value', 'Hash', 'Indicator', 'Sha256', 'SHA-256', 'SHA1', 'MD5')
if (-not @($rows[0].PSObject.Properties.Name | Where-Object { $_ -in $valueNames }).Count) {
    throw 'No hash column found. Use Indicator Value as the CSV header.'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $inputFile.DirectoryName "$($inputFile.BaseName).MDE-DoD-Validated.csv"
}
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ($OutputPath -eq $inputFile.FullName) { throw 'Output must not overwrite the input CSV.' }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $OutputPath) -PathType Container)) {
    throw 'The output directory must already exist in approved storage.'
}
$completed = [Collections.Generic.HashSet[int]]::new()
$failureStatuses = @('RequestFailed', 'Unauthorized', 'Forbidden', 'RateLimited', 'ResponseMismatch')
$hadFailures = $false
$columns = @('InputRow', 'InputFileSha256', 'TenantId', 'ApiBaseUri', 'IndicatorValue', 'IndicatorType',
    'LookupStatus', 'HttpStatus', 'DeterminationType', 'ThreatName', 'GlobalPrevalence',
    'GlobalFirstObserved', 'GlobalLastObserved', 'Size', 'IsPeFile', 'Signer',
    'IsValidCertificate', 'Error', 'QueriedAtUtc')
if (Test-Path -LiteralPath $OutputPath) {
    if (-not $Resume) { throw 'Output already exists. Use Resume or choose a new OutputPath.' }
    $previous = @(Import-Csv -LiteralPath $OutputPath)
    if ($previous.Count -eq 0 -or ($previous[0].PSObject.Properties.Name -join ',') -ne ($columns -join ',')) {
        throw 'The resume report is empty or has an invalid schema.'
    }
    foreach ($entry in $previous) {
        $rowNumber = 0
        if ($entry.InputFileSha256 -ne $inputDigest -or $entry.TenantId -ne $TenantId.ToString() -or
            $entry.ApiBaseUri -ne $apiBase -or -not [int]::TryParse($entry.InputRow, [ref]$rowNumber) -or
            $rowNumber -lt 1 -or $rowNumber -gt $rows.Count -or -not $completed.Add($rowNumber)) {
            throw 'The resume report does not match this input and tenant, or contains duplicate or invalid rows.'
        }
        if ($entry.LookupStatus -notin @('Found', 'NotFound', 'Unsupported', 'InvalidInput') + $failureStatuses) {
            throw 'The resume report contains an invalid lookup status.'
        }
        if ($entry.LookupStatus -in $failureStatuses -or $entry.LookupStatus -in @('InvalidInput', 'Unsupported')) {
            $hadFailures = $true
        }
    }
} elseif ($Resume) {
    throw 'Resume requires an existing report.'
}

Import-Module Az.Accounts -MinimumVersion 3.0.0 -ErrorAction Stop
Assert-MdeContext
Write-Output "Rows: $($rows.Count). Already recorded: $($completed.Count). Report: $OutputPath"
Write-Output 'Only the DoD MDE file API is used. No indicators are modified.'
try {
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $rowNumber = $index + 1
        if ($completed.Contains($rowNumber)) { continue }
        $row = $rows[$index]
        $hash = ([string](Get-Field $row $valueNames)).Trim().ToLowerInvariant()
        $declaredType = ([string](Get-Field $row @('Indicator Type', 'IndicatorType', 'Type'))).Trim()
        $type = switch -Regex ($hash) {
            '^[a-f0-9]{64}$' { 'FileSha256'; break }
            '^[a-f0-9]{40}$' { 'FileSha1'; break }
            '^[a-f0-9]{32}$' { 'FileMd5'; break }
            default { 'Unknown' }
        }
        if ($type -eq 'Unknown' -or ($declaredType -and $declaredType -ne $type)) {
            $lookup = @{ Status = 'InvalidInput'; HttpStatus = ''; File = $null
                Error = 'Invalid hash or a declared type that does not match its length. No request sent.' }
        } elseif ($type -eq 'FileMd5') {
            $lookup = @{ Status = 'Unsupported'; HttpStatus = ''; File = $null
                Error = 'This API accepts SHA1 or SHA256, not MD5. No request sent.' }
        } else {
            $lookup = Get-MdeFile -Hash $hash
        }
        $file = $lookup.File
        $record = [pscustomobject][ordered]@{
            InputRow = $rowNumber
            InputFileSha256 = $inputDigest
            TenantId = $TenantId.ToString()
            ApiBaseUri = $apiBase
            IndicatorValue = if ($type -ne 'Unknown') { $hash } else { '' }
            IndicatorType = $type
            LookupStatus = $lookup.Status
            HttpStatus = $lookup.HttpStatus
            DeterminationType = Get-Field $file @('determinationType')
            ThreatName = Get-Field $file @('determinationValue')
            GlobalPrevalence = Get-Field $file @('globalPrevalence')
            GlobalFirstObserved = Get-Field $file @('globalFirstObserved')
            GlobalLastObserved = Get-Field $file @('globalLastObserved')
            Size = Get-Field $file @('size')
            IsPeFile = Get-Field $file @('isPeFile')
            Signer = Get-Field $file @('signer')
            IsValidCertificate = Get-Field $file @('isValidCertificate')
            Error = $lookup.Error
            QueriedAtUtc = [datetimeoffset]::UtcNow.ToString('o')
        }
        foreach ($property in $record.PSObject.Properties) {
            if ($property.Value -is [string] -and $property.Value -match '^\s*[=+@\-]') {
                $property.Value = "'" + $property.Value
            }
        }
        $record | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8 -Append
        Write-Output "[$rowNumber/$($rows.Count)] $type : $($lookup.Status)"
        if ($lookup.Status -in $failureStatuses -or $lookup.Status -in @('InvalidInput', 'Unsupported')) {
            $hadFailures = $true
            Write-Warning "Row $rowNumber : $($lookup.Error)"
        }
        if ($lookup.Status -in @('Unauthorized', 'Forbidden', 'ResponseMismatch')) {
            throw "Stopped on $($lookup.Status). Completed rows are saved in $OutputPath."
        }
    }
} finally {
    $accessToken = $null
    $requestClock.Stop()
}
Write-Output "Saved: $OutputPath"
if ($hadFailures) {
    throw 'The report contains failed, invalid, or unsupported rows. Review LookupStatus and Error. Recorded rows are skipped on resume.'
}
```

## Resume an interrupted run

Each completed row is appended to the report immediately. Keep the input file
unchanged and use the same tenant, environment script, and report path.

For Commercial:

```powershell
.\Validate-HashIOCs-Commercial.ps1 -InputPath '.\CustomTiIndicators.20261104.csv' -TenantId $tenantId -Resume
```

For GCC High:

```powershell
.\Validate-HashIOCs-GCCH.ps1 -InputPath '.\CustomTiIndicators.20261104.csv' -TenantId $tenantId -Resume
```

For DoD:

```powershell
.\Validate-HashIOCs-DoD.ps1 -InputPath '.\CustomTiIndicators.20261104.csv' -TenantId $tenantId -Resume
```

If you start a new PowerShell window, repeat the appropriate authentication steps
before resuming. Refreshing tokens can still require a new interactive sign in
when organizational policies expire or revoke the session. The script does not
bypass those policies or sign in automatically.

Resume checks the input file SHA256, tenant, API base, row numbers, and report
schema. It skips every recorded row, including errors. To retry failed lookups,
create a separate CSV containing those hash values and choose a fresh report.
An edited or interrupted report must be checked before reuse; invalid resume
metadata or schema is rejected.

Existing reports are not overwritten. Use `-OutputPath` to choose another approved
path. For example, with the DoD script:

```powershell
.\Validate-HashIOCs-DoD.ps1 -InputPath '.\Hash.csv' -TenantId $tenantId -OutputPath '.\ReviewResults.csv'
```

Supply that same `-OutputPath` with `-Resume`. Do not run multiple processes
against the same report. Keep the report closed in Excel while appending rows.

## Request pacing and failures

The file information API documents limits of 100 calls per minute and 1,500 calls
per hour. These scripts space request starts by at least 2.5 seconds, giving about
1,440 requests per hour before retries and other delays. For 5,716 valid rows,
allow about four hours plus retries. Other callers may share the allowance.

HTTP 429 and server errors receive up to five retries. The scripts honor
`Retry-After`, including a date value. Transport failures also receive bounded
retries. HTTP 401 triggers one token refresh; persistent 401, HTTP 403, or a
mismatched file response stops the run after recording that failure.

Reports with request failures, invalid input, or unsupported values end with an
explicit error so the run cannot appear entirely successful. Completed results
remain saved. Fix access or connectivity through the approved process, not by
changing cloud targets, disabling security controls, or granting unapproved access.

## Read the results

| Field | Meaning |
|---|---|
| `IndicatorValue`, `IndicatorType` | Input hash and inferred type. |
| `LookupStatus` | Lookup outcome, separate from the malware determination. |
| `HttpStatus` | API HTTP status when available. |
| `DeterminationType` | Microsoft's file determination, when returned. |
| `ThreatName` | The API's `determinationValue`, such as a detection name. |
| `GlobalPrevalence` | The prevalence value returned by the API, not a local device inventory. |
| `GlobalFirstObserved`, `GlobalLastObserved` | Observation timestamps returned by the API. |
| `Size`, `IsPeFile`, `Signer`, `IsValidCertificate` | Available file and signing details. |
| `InputRow`, `InputFileSha256` | Input identity used for resume and audit. |
| `TenantId`, `ApiBaseUri`, `QueriedAtUtc` | Query target and UTC record timestamp. |
| `Error` | Explanation of an unknown, unsupported, or failed lookup. |

`Found` means the API returned a matching file record. It does not necessarily
mean malware. `NotFound` means HTTP 404, not clean or safe to remove. Missing fields
remain empty rather than being treated as negative verdicts. Invalid hash text is
not copied into the indicator value field. Text beginning with a spreadsheet
formula marker is prefixed with an apostrophe in the report.

The API does not provide the VirusTotal detection ratio, individual vendor
results, or proof of the current antivirus signature coverage on every endpoint.
Do not automatically delete custom indicators based on a malware determination,
an empty determination, or a missing file record. Preserve indicators required by
an active investigation, policy, or custom detection workflow.

## Data handling statement

For an actual run whose destinations and storage have been verified, describe the
behavior accurately:

> The script queried Microsoft Defender for Endpoint using authorized access to
> the selected tenant and cloud. It made no direct requests to VirusTotal or other
> external reputation services. Input and output stayed in approved organizational
> storage.

Use the final sentence only when it is true for the host and storage used.
The code does not establish that data never left a tenant boundary. Microsoft
service processing, global intelligence, authentication caches, and logging remain
subject to the applicable configuration and agreement. The script does not export
access tokens; authentication libraries retain their configured cache behavior.

## Local checks

The included [synthetic test runner](./Tests/Test-ValidateHashIOCs.ps1) replaces
module loading, identity lookup, network requests, and sleeps with local fixtures.
It does not sign in or query a tenant. Run from this page's folder:

```powershell
.\Tests\Test-ValidateHashIOCs.ps1 -ScriptPath '.\Validate-HashIOCs-Commercial.ps1' -AzureEnvironment AzureCloud -ApiBaseUri 'https://api.security.microsoft.com' -TokenResource 'https://api.securitycenter.microsoft.com'
.\Tests\Test-ValidateHashIOCs.ps1 -ScriptPath '.\Validate-HashIOCs-GCCH.ps1'
.\Tests\Test-ValidateHashIOCs.ps1 -ScriptPath '.\Validate-HashIOCs-DoD.ps1'
```

These checks cover input validation, cloud and tenant rejection, returned file
identity, missing results, retries, token refresh, CSV handling, and resume.
Passing synthetic checks does not establish live permissions or government
service availability. Validate a small approved input in your target environment
before a full batch.

## References

1. [Get file information API](https://learn.microsoft.com/defender-endpoint/api/get-file-information)
2. [File resource fields](https://learn.microsoft.com/defender-endpoint/api/files)
3. [MDE government API endpoints](https://learn.microsoft.com/defender-endpoint/gov#api)
4. [Get an MDE access token](https://learn.microsoft.com/defender-endpoint/api/exposed-apis-create-app-nativeapp)
5. [Original VT based bulk IOC workflow](../Bulk%20IOC%20Validation/README.md)
