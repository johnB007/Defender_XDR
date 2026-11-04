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
