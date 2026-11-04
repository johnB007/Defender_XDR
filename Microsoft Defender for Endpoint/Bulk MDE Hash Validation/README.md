# Bulk MDE Hash Validation

Review a CSV of file hash indicators using Microsoft Defender for Endpoint file
intelligence. Choose the script for Commercial, GCC High (GCCH), or DoD.

These scripts query existing Microsoft file records. They do not call VirusTotal,
submit samples, download malware, change indicators, or run endpoint response
actions. Run them on an approved workstation or automation host, not in MDE API
Explorer or Live Response.

## Choose the correct environment

| Environment | Script | Defender portal | File API base | Azure CLI cloud |
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
2. Azure CLI 2.54 or later on PATH, installed through an approved software
   distribution process. Token output must include UTC epoch `expires_on`.
   No Az.Accounts module is required.
3. Approved MDE `File.Read.All` delegated access and the required user role
   permissions, including View Data, for a user session. An existing approved
   certificate service principal or managed identity instead needs approved
   application `File.Read.All` access to MDE.
   Client consent or permission grants may require a tenant administrator.
   Azure subscription permissions alone are insufficient.
4. An approved execution host, input location, and output location for the
   selected environment.
5. HTTPS access to the selected MDE API and the environment's identity endpoints.
   The scripts are not offline tools.

Check your PowerShell and CLI installation:

```powershell
$PSVersionTable.PSVersion
Get-Command az -CommandType Application
az version
```

If the CLI is missing, have it installed from a source approved for that host.
Do not copy a corporate laptop's package proxy or repository settings into a
government environment. The scripts do not install software or change account,
cloud, tenant, package source, or CLI configuration.

No Excel installation, ImportExcel module, VirusTotal account, or VirusTotal API
key is required. Signing into a browser does not by itself establish an Azure CLI
session. Azure CLI and Az.Accounts use separate authentication caches;
`Connect-AzAccount` is not a substitute for CLI authentication.
Successful access in API Explorer also does not establish that the CLI client
has the necessary MDE consent or permissions.

## Authentication without device code flow

The file information API is an MDE API, not an Azure Resource Manager API.
Azure CLI supplies an OAuth token for its fixed MDE resource; the script then
calls the selected MDE file API. Read only access still requires authentication,
MDE permissions, client consent, and compliance with Conditional Access.
Querying does not itself require local administrator rights, but installation
and organizational permission approval can require an administrator.

Every lookup script consumes an existing authenticated Azure CLI session only.
It never calls `az login`, selects a cloud or tenant, or attempts device code
authentication. It only runs `az cloud show`, `az account show`, and
`az account get-access-token`. It checks the current cloud, account environment,
and active tenant before requests and token refresh. It requests the fixed
resource for the CURRENT verified account without a `--tenant` argument.
The mandatory script `-TenantId` is still checked against both the active account
and returned token tenant metadata before any API request. It also checks UTC
epoch expiry and sends a SecureString bearer token. No token is printed or written
by the lookup script. CLI stdout and stderr are captured only in memory. Raw
error details are suppressed; the known unsupported MSI audience error is mapped
to a fixed credential safe diagnostic, and other failures are explicit.
Azure CLI still maintains its own normal credential cache. Plaintext token JSON
exists briefly in process memory, so do not enable tracing or capture process
memory while handling credentials.

Existing local user and approved certificate service principal sessions can be
reused when the CLI supplies a valid MDE token and the required metadata.
Cloud Shell and managed identity support is CONDITIONAL on the existing credential
being able to obtain that MDE audience. The command form does not itself make
the hosted credential capable of requesting it or establish MDE permissions.
Account user labels are not used to infer authorization. A matching account
tenant and environment, token `tenant`, `tokenType`, `accessToken`, and future
UTC epoch `expires_on` are required for every session type. Missing token tenant
metadata is rejected with an explicit limitation, never inferred from the
account or silently defaulted.

Azure CLI documents that `get-access-token --tenant` is not supported for Cloud
Shell or managed identity. Omitting that CLI option does not remove the script's
tenant guard or allow it to choose another tenant. A returned token for a
different tenant, including after a context race or refresh, is rejected.
The tested Commercial Cloud Shell environment rejected the MDE audience with:

```text
Audience https://api.securitycenter.microsoft.com is not a supported MSI token audience.
```

Native Cloud Shell authentication is therefore NOT working for MDE in that
environment. This credential audience restriction is separate from the user's
MDE `File.Read.All` access. Adding a user role does not remove a hosted credential
audience restriction. No successful live Cloud Shell or managed identity MDE
lookup has been established. Government hosted environments have not been tested.
Do not try audience aliases, another cloud, `az logout`, or automatic `az login`
to work around this error. Headless interactive login can fall back to device
code, which does not meet the strict no device flow requirement.

For an already authenticated Cloud Shell session, do not repeat login or cloud
setup just to run these scripts. Use a compatible hosted environment already
selected for the authorized cloud and tenant. Commercial, GCC High, and DoD each
require their matching environment and MDE authorization. Not every Cloud Shell
session can obtain an MDE scoped token. Authentication support does not imply
client consent, tenant permission, API availability, or storage approval.

Practical alternatives that do not add device code authentication to these
scripts are an already authenticated approved desktop CLI session established
using an accepted WAM or browser method, or an existing approved certificate
service principal with MDE application permission. These alternatives still need
approved client consent and authorization. They do not assume that the user can
create an application or grant permissions. For a single hash, the MDE API
Explorer can be used manually with already authorized portal access; this is
not the bulk CLI workflow.

Select and authenticate to the authorized cloud manually, outside the lookup
script. Commercial uses `az cloud set --name AzureCloud`; GCC High and DoD use
`az cloud set --name AzureUSGovernment`. These manual commands change your CLI
configuration. Review the intended cloud and tenant before using them.

For an existing approved certificate service principal, this manual setup uses
no device code flow. It does not create an app or grant permissions. Use only a
certificate and application already approved for the selected tenant:

```powershell
# First manually select the authorized cloud as described above.
$tenantId = Read-Host 'Enter the approved tenant ID'
$appId = Read-Host 'Enter the existing approved application ID'
$certificatePath = Read-Host 'Enter the approved certificate PEM path on this host'
az login --service-principal --username $appId --certificate $certificatePath --tenant $tenantId --output none --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Authentication failed. Stop; do not fall back to another login method.' }
```

For interactive users, Azure CLI normally uses Windows Web Account Manager
(WAM) on supported Windows systems or a browser on other supported systems.
However, `az login` MAY fall back to device code when a browser is unavailable.
Omitting `--use-device-code` does NOT prevent that fallback. Do not use ordinary
interactive `az login` automation as a strict no device flow guarantee. Reuse an
already approved user session only if its authentication method meets your
policy; otherwise use the existing approved certificate workflow above.
Do not use password authentication or add a device code fallback.

If existing authentication is expired, missing, or cannot supply the MDE token,
the lookup fails without initiating sign in. Resolve access outside the script,
then resume. The scripts cannot bypass MFA, Conditional Access, or consent.

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

## Linux PowerShell and Azure Cloud Shell

These are PowerShell 7 commands, not Bash commands. Linux paths are case
sensitive; a Windows path such as `C:\Users\...` does not refer to a file in
Cloud Shell. `./Hash.sample.csv` refers to a CSV in your current directory.
`./Microsoft` refers to a folder beneath that directory. The folder name alone
does not establish where a script was uploaded or whether it exists.

Path discovery below is separate from authentication. In the Commercial Cloud
Shell session that reported the unsupported MSI audience above, finding the
script will NOT fix token acquisition. Use an approved credential alternative
before attempting an actual lookup; the script will fail without sending a
file request if the hosted credential still rejects the MDE audience.

If your current directory contains `Hash.sample.csv` and a `Microsoft` folder,
find only the Commercial script under that folder and require exactly one match:

```powershell
$tenantId = Read-Host 'Enter the approved Commercial tenant ID'
$matches = @(Get-ChildItem -LiteralPath './Microsoft' -Filter 'Validate-HashIOCs-Commercial.ps1' -File -Recurse -ErrorAction Stop)
if ($matches.Count -ne 1) {
    throw "Expected exactly one Commercial script under ./Microsoft; found $($matches.Count). Upload the current script or resolve duplicates before running."
}
$script = $matches[0]
& $script.FullName -InputPath './Hash.sample.csv' -TenantId $tenantId
```

For GCC High, use the same commands with
`-Filter 'Validate-HashIOCs-GCCH.ps1'` and the approved GCC High tenant ID.
For DoD, use `-Filter 'Validate-HashIOCs-DoD.ps1'` and the approved DoD tenant ID.
Require exactly one match in each case and update the error's environment label
to match your choice. Do not select the first file from multiple matches.
Each script checks the current CLI cloud and tenant, so none of these commands
selects or authenticates to another environment.

If the matching script is beside the CSV instead, use the direct relative
commands in the cloud sections below. Both forms work in local PowerShell;
use paths that actually exist on that host. `-Resume` can be appended after an
interruption using the same CSV, tenant, script, and report. If the scripts were
uploaded before this update, upload the current version before trying again.
No remote directory contents or live tenant access have been verified here.

## Commercial

### Authenticate and run Commercial

Use an existing authorized `AzureCloud` session for the approved Commercial
tenant. If setup is needed, complete it outside the script using the guidance
above. In PowerShell 7, change to the approved folder containing the script and
CSV, then run:

```powershell
$tenantId = Read-Host 'Enter the approved Commercial tenant ID'
./Validate-HashIOCs-Commercial.ps1 -InputPath './Hash.sample.csv' -TenantId $tenantId
```

There is no sign in prompt from this script. It refuses a government cloud,
a different active tenant, or unusable existing authentication.

Default report: `Hash.sample.MDE-Commercial-Validated.csv`.

### Complete Commercial script

Save as `Validate-HashIOCs-Commercial.ps1`:

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Look up hash indicators through the Commercial MDE file information API.
.DESCRIPTION
    Run on an approved workstation, not in MDE Live Response. Requires an existing
    Azure CLI AzureCloud session with File.Read.All access. Does not sign
    in, change contexts, call VirusTotal, submit samples, or modify indicators.
    Saves each result immediately. Resume requires the same input file and tenant.
.PARAMETER TenantId
    The Commercial tenant to verify against the existing Azure CLI session.
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
$unsupportedAudienceError = "Audience $tokenResource is not a supported MSI token audience. The existing hosted credential cannot supply an MDE token. No lookup, login, logout, or fallback was attempted."
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

function Invoke-MdeAzJson {
    param([string[]]$Arguments)
    $raw = $null
    try {
        # Capture both streams in memory. Never print raw CLI output or errors.
        $LASTEXITCODE = 0
        $raw = @(& $script:azureCli @Arguments --output json --only-show-errors 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'CLI failed.' }
        $stdout = @($raw | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] })
        $result = ($stdout -join "`n") | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($result -isnot [Collections.IDictionary]) { throw 'Invalid CLI JSON.' }
        return $result
    } catch {
        if (($raw -join "`n") -match ('Audience\s+' + [regex]::Escape($tokenResource) + '\s+is not a supported MSI token audience\.')) {
            throw $unsupportedAudienceError
        }
        throw 'Azure CLI could not supply valid session data. Verify the approved existing CLI authentication outside this script. No login or fallback was attempted.'
    } finally {
        $raw = $null
        $stdout = $null
    }
}

function Assert-MdeContext {
    $cloud = Invoke-MdeAzJson -Arguments @('cloud', 'show')
    $context = Invoke-MdeAzJson -Arguments @('account', 'show')
    if ($cloud['name'] -isnot [string] -or $context['environmentName'] -isnot [string] -or
        $context['tenantId'] -isnot [string] -or
        $cloud['name'] -ne 'AzureCloud' -or $context['environmentName'] -ne 'AzureCloud' -or
        $context['tenantId'] -ne $TenantId.ToString()) {
        throw 'The existing Azure CLI session is not AzureCloud in the requested tenant. No lookup is allowed.'
    }
}

function Get-MdeAccessToken {
    Assert-MdeContext
    if ($null -eq $script:accessToken -or $script:tokenExpiry -le [datetimeoffset]::UtcNow.AddMinutes(5)) {
        $token = $null
        $tokenError = 'Azure CLI could not supply a valid MDE token for the requested tenant with a future UTC expires_on. Authenticate outside this script. No login or fallback was attempted.'
        try {
            # Use the verified current account. Cloud Shell and MSI do not support --tenant here.
            $token = Invoke-MdeAzJson -Arguments @('account', 'get-access-token', '--resource', $tokenResource)
            if ($token['tenant'] -isnot [string] -or [string]::IsNullOrWhiteSpace($token['tenant'])) {
                $tokenError = 'Azure CLI token JSON has no usable tenant metadata. This session cannot be verified; no lookup is allowed. No login or fallback was attempted.'
                throw 'Unverifiable token tenant.'
            }
            if ($token['tenant'] -ne $TenantId.ToString()) {
                $tokenError = 'Azure CLI returned a token for a different tenant. No lookup is allowed. No login or fallback was attempted.'
                throw 'Token tenant mismatch.'
            }
            $epoch = 0L
            if ($token['tokenType'] -isnot [string] -or $token['tokenType'] -ne 'Bearer' -or
                $token['accessToken'] -isnot [string] -or [string]::IsNullOrWhiteSpace($token['accessToken']) -or
                -not ($token['expires_on'] -is [string] -or $token['expires_on'] -is [long] -or
                    $token['expires_on'] -is [int]) -or
                "$($token['expires_on'])" -notmatch '^[0-9]+$' -or
                -not [long]::TryParse("$($token['expires_on'])", [ref]$epoch)) {
                throw 'Invalid token metadata.'
            }
            $expiry = [datetimeoffset]::FromUnixTimeSeconds($epoch)
            if ($expiry -le [datetimeoffset]::UtcNow) { throw 'Expired token.' }
            $secureToken = [securestring]::new()
            for ($i = 0; $i -lt $token['accessToken'].Length; $i++) {
                $secureToken.AppendChar($token['accessToken'][$i])
            }
            $secureToken.MakeReadOnly()
            $script:accessToken = $secureToken
            $script:tokenExpiry = $expiry
        } catch {
            $script:accessToken = $null
            if ($_.Exception.Message -eq $unsupportedAudienceError) { throw $unsupportedAudienceError }
            throw $tokenError
        } finally {
            if ($null -ne $token) { $token['accessToken'] = $null }
            $token = $null
        }
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

try {
    $azureCli = Get-Command az -CommandType Application -ErrorAction Stop | Select-Object -First 1
} catch {
    throw 'Azure CLI (az) is required on PATH. Use an approved installation and authenticate outside this script.'
}
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

Use the approved GCC High host and storage with an existing authorized
`AzureUSGovernment` session for the approved GCC High tenant. If setup is needed,
complete it outside the script using the guidance above. In PowerShell 7, run:

```powershell
$tenantId = Read-Host 'Enter the approved GCC High tenant ID'
./Validate-HashIOCs-GCCH.ps1 -InputPath './Hash.sample.csv' -TenantId $tenantId
```

There is no sign in prompt from this script. It refuses a Commercial cloud,
a different active tenant, or unusable existing authentication. The government
API hostname alone cannot distinguish a GCC High tenant from a DoD tenant;
verify the tenant ID before authenticating outside the script.

Default report: `Hash.sample.MDE-GCCH-Validated.csv`.

### Complete GCC High script

Save as `Validate-HashIOCs-GCCH.ps1`:

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Look up hash indicators through the GCC High MDE file information API.
.DESCRIPTION
    Run on an approved workstation, not in MDE Live Response. Requires an existing
    Azure CLI AzureUSGovernment session with File.Read.All access. Does not sign
    in, change contexts, call VirusTotal, submit samples, or modify indicators.
    Saves each result immediately. Resume requires the same input file and tenant.
.PARAMETER TenantId
    The GCC High tenant to verify against the existing Azure CLI session.
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
$unsupportedAudienceError = "Audience $tokenResource is not a supported MSI token audience. The existing hosted credential cannot supply an MDE token. No lookup, login, logout, or fallback was attempted."
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

function Invoke-MdeAzJson {
    param([string[]]$Arguments)
    $raw = $null
    try {
        # Capture both streams in memory. Never print raw CLI output or errors.
        $LASTEXITCODE = 0
        $raw = @(& $script:azureCli @Arguments --output json --only-show-errors 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'CLI failed.' }
        $stdout = @($raw | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] })
        $result = ($stdout -join "`n") | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($result -isnot [Collections.IDictionary]) { throw 'Invalid CLI JSON.' }
        return $result
    } catch {
        if (($raw -join "`n") -match ('Audience\s+' + [regex]::Escape($tokenResource) + '\s+is not a supported MSI token audience\.')) {
            throw $unsupportedAudienceError
        }
        throw 'Azure CLI could not supply valid session data. Verify the approved existing CLI authentication outside this script. No login or fallback was attempted.'
    } finally {
        $raw = $null
        $stdout = $null
    }
}

function Assert-MdeContext {
    $cloud = Invoke-MdeAzJson -Arguments @('cloud', 'show')
    $context = Invoke-MdeAzJson -Arguments @('account', 'show')
    if ($cloud['name'] -isnot [string] -or $context['environmentName'] -isnot [string] -or
        $context['tenantId'] -isnot [string] -or
        $cloud['name'] -ne 'AzureUSGovernment' -or $context['environmentName'] -ne 'AzureUSGovernment' -or
        $context['tenantId'] -ne $TenantId.ToString()) {
        throw 'The existing Azure CLI session is not AzureUSGovernment in the requested tenant. No lookup is allowed.'
    }
}

function Get-MdeAccessToken {
    Assert-MdeContext
    if ($null -eq $script:accessToken -or $script:tokenExpiry -le [datetimeoffset]::UtcNow.AddMinutes(5)) {
        $token = $null
        $tokenError = 'Azure CLI could not supply a valid MDE token for the requested tenant with a future UTC expires_on. Authenticate outside this script. No login or fallback was attempted.'
        try {
            # Use the verified current account. Cloud Shell and MSI do not support --tenant here.
            $token = Invoke-MdeAzJson -Arguments @('account', 'get-access-token', '--resource', $tokenResource)
            if ($token['tenant'] -isnot [string] -or [string]::IsNullOrWhiteSpace($token['tenant'])) {
                $tokenError = 'Azure CLI token JSON has no usable tenant metadata. This session cannot be verified; no lookup is allowed. No login or fallback was attempted.'
                throw 'Unverifiable token tenant.'
            }
            if ($token['tenant'] -ne $TenantId.ToString()) {
                $tokenError = 'Azure CLI returned a token for a different tenant. No lookup is allowed. No login or fallback was attempted.'
                throw 'Token tenant mismatch.'
            }
            $epoch = 0L
            if ($token['tokenType'] -isnot [string] -or $token['tokenType'] -ne 'Bearer' -or
                $token['accessToken'] -isnot [string] -or [string]::IsNullOrWhiteSpace($token['accessToken']) -or
                -not ($token['expires_on'] -is [string] -or $token['expires_on'] -is [long] -or
                    $token['expires_on'] -is [int]) -or
                "$($token['expires_on'])" -notmatch '^[0-9]+$' -or
                -not [long]::TryParse("$($token['expires_on'])", [ref]$epoch)) {
                throw 'Invalid token metadata.'
            }
            $expiry = [datetimeoffset]::FromUnixTimeSeconds($epoch)
            if ($expiry -le [datetimeoffset]::UtcNow) { throw 'Expired token.' }
            $secureToken = [securestring]::new()
            for ($i = 0; $i -lt $token['accessToken'].Length; $i++) {
                $secureToken.AppendChar($token['accessToken'][$i])
            }
            $secureToken.MakeReadOnly()
            $script:accessToken = $secureToken
            $script:tokenExpiry = $expiry
        } catch {
            $script:accessToken = $null
            if ($_.Exception.Message -eq $unsupportedAudienceError) { throw $unsupportedAudienceError }
            throw $tokenError
        } finally {
            if ($null -ne $token) { $token['accessToken'] = $null }
            $token = $null
        }
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

try {
    $azureCli = Get-Command az -CommandType Application -ErrorAction Stop | Select-Object -First 1
} catch {
    throw 'Azure CLI (az) is required on PATH. Use an approved installation and authenticate outside this script.'
}
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
storage or query the Commercial API. Use an existing authorized
`AzureUSGovernment` session for the approved DoD tenant. If setup is needed,
complete it outside the script using the guidance above. In PowerShell 7, run:

```powershell
$tenantId = Read-Host 'Enter the approved DoD tenant ID'
./Validate-HashIOCs-DoD.ps1 -InputPath './Hash.sample.csv' -TenantId $tenantId
```

There is no sign in prompt from this script. It refuses a Commercial cloud,
a different active tenant, or unusable existing authentication.
It does not establish IL5 compliance or authorize a transfer.
The host, storage, network, identity, and service agreement remain part of the
approved boundary.

Default report: `Hash.sample.MDE-DoD-Validated.csv`.

### Complete DoD script

Save as `Validate-HashIOCs-DoD.ps1`:

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Look up hash indicators through the DoD MDE file information API.
.DESCRIPTION
    Run on an approved workstation, not in MDE Live Response. Requires an existing
    Azure CLI AzureUSGovernment session with File.Read.All access. Does not sign
    in, change contexts, call VirusTotal, submit samples, or modify indicators.
    Saves each result immediately. Resume requires the same input file and tenant.
.PARAMETER TenantId
    The DoD tenant to verify against the existing Azure CLI session.
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
$unsupportedAudienceError = "Audience $tokenResource is not a supported MSI token audience. The existing hosted credential cannot supply an MDE token. No lookup, login, logout, or fallback was attempted."
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

function Invoke-MdeAzJson {
    param([string[]]$Arguments)
    $raw = $null
    try {
        # Capture both streams in memory. Never print raw CLI output or errors.
        $LASTEXITCODE = 0
        $raw = @(& $script:azureCli @Arguments --output json --only-show-errors 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'CLI failed.' }
        $stdout = @($raw | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] })
        $result = ($stdout -join "`n") | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($result -isnot [Collections.IDictionary]) { throw 'Invalid CLI JSON.' }
        return $result
    } catch {
        if (($raw -join "`n") -match ('Audience\s+' + [regex]::Escape($tokenResource) + '\s+is not a supported MSI token audience\.')) {
            throw $unsupportedAudienceError
        }
        throw 'Azure CLI could not supply valid session data. Verify the approved existing CLI authentication outside this script. No login or fallback was attempted.'
    } finally {
        $raw = $null
        $stdout = $null
    }
}

function Assert-MdeContext {
    $cloud = Invoke-MdeAzJson -Arguments @('cloud', 'show')
    $context = Invoke-MdeAzJson -Arguments @('account', 'show')
    if ($cloud['name'] -isnot [string] -or $context['environmentName'] -isnot [string] -or
        $context['tenantId'] -isnot [string] -or
        $cloud['name'] -ne 'AzureUSGovernment' -or $context['environmentName'] -ne 'AzureUSGovernment' -or
        $context['tenantId'] -ne $TenantId.ToString()) {
        throw 'The existing Azure CLI session is not AzureUSGovernment in the requested tenant. No lookup is allowed.'
    }
}

function Get-MdeAccessToken {
    Assert-MdeContext
    if ($null -eq $script:accessToken -or $script:tokenExpiry -le [datetimeoffset]::UtcNow.AddMinutes(5)) {
        $token = $null
        $tokenError = 'Azure CLI could not supply a valid MDE token for the requested tenant with a future UTC expires_on. Authenticate outside this script. No login or fallback was attempted.'
        try {
            # Use the verified current account. Cloud Shell and MSI do not support --tenant here.
            $token = Invoke-MdeAzJson -Arguments @('account', 'get-access-token', '--resource', $tokenResource)
            if ($token['tenant'] -isnot [string] -or [string]::IsNullOrWhiteSpace($token['tenant'])) {
                $tokenError = 'Azure CLI token JSON has no usable tenant metadata. This session cannot be verified; no lookup is allowed. No login or fallback was attempted.'
                throw 'Unverifiable token tenant.'
            }
            if ($token['tenant'] -ne $TenantId.ToString()) {
                $tokenError = 'Azure CLI returned a token for a different tenant. No lookup is allowed. No login or fallback was attempted.'
                throw 'Token tenant mismatch.'
            }
            $epoch = 0L
            if ($token['tokenType'] -isnot [string] -or $token['tokenType'] -ne 'Bearer' -or
                $token['accessToken'] -isnot [string] -or [string]::IsNullOrWhiteSpace($token['accessToken']) -or
                -not ($token['expires_on'] -is [string] -or $token['expires_on'] -is [long] -or
                    $token['expires_on'] -is [int]) -or
                "$($token['expires_on'])" -notmatch '^[0-9]+$' -or
                -not [long]::TryParse("$($token['expires_on'])", [ref]$epoch)) {
                throw 'Invalid token metadata.'
            }
            $expiry = [datetimeoffset]::FromUnixTimeSeconds($epoch)
            if ($expiry -le [datetimeoffset]::UtcNow) { throw 'Expired token.' }
            $secureToken = [securestring]::new()
            for ($i = 0; $i -lt $token['accessToken'].Length; $i++) {
                $secureToken.AppendChar($token['accessToken'][$i])
            }
            $secureToken.MakeReadOnly()
            $script:accessToken = $secureToken
            $script:tokenExpiry = $expiry
        } catch {
            $script:accessToken = $null
            if ($_.Exception.Message -eq $unsupportedAudienceError) { throw $unsupportedAudienceError }
            throw $tokenError
        } finally {
            if ($null -ne $token) { $token['accessToken'] = $null }
            $token = $null
        }
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

try {
    $azureCli = Get-Command az -CommandType Application -ErrorAction Stop | Select-Object -First 1
} catch {
    throw 'Azure CLI (az) is required on PATH. Use an approved installation and authenticate outside this script.'
}
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
./Validate-HashIOCs-Commercial.ps1 -InputPath './Hash.sample.csv' -TenantId $tenantId -Resume
```

For GCC High:

```powershell
./Validate-HashIOCs-GCCH.ps1 -InputPath './Hash.sample.csv' -TenantId $tenantId -Resume
```

For DoD:

```powershell
./Validate-HashIOCs-DoD.ps1 -InputPath './Hash.sample.csv' -TenantId $tenantId -Resume
```

In a new PowerShell window, set `$tenantId` again and verify the existing CLI
session still targets the approved cloud and tenant. A new window does not
necessarily require a new login. If session policies require authentication,
complete it outside the script with an approved method that meets your no device
flow policy, then resume. The script never initiates or falls back to sign in.

Resume checks the input file SHA256, tenant, API base, row numbers, and report
schema. It skips every recorded row, including errors. To retry failed lookups,
create a separate CSV containing those hash values and choose a fresh report.
An edited or interrupted report must be checked before reuse; invalid resume
metadata or schema is rejected.

Existing reports are not overwritten. Use `-OutputPath` to choose another approved
path. For example, with the DoD script:

```powershell
./Validate-HashIOCs-DoD.ps1 -InputPath './Hash.csv' -TenantId $tenantId -OutputPath './ReviewResults.csv'
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
CLI discovery, CLI session and token commands, network requests, and sleeps with
local fixtures.
It does not sign in or query a tenant. Run from this page's folder:

```powershell
./Tests/Test-ValidateHashIOCs.ps1 -ScriptPath './Validate-HashIOCs-Commercial.ps1' -AzureEnvironment AzureCloud -ApiBaseUri 'https://api.security.microsoft.com' -TokenResource 'https://api.securitycenter.microsoft.com'
./Tests/Test-ValidateHashIOCs.ps1 -ScriptPath './Validate-HashIOCs-GCCH.ps1'
./Tests/Test-ValidateHashIOCs.ps1 -ScriptPath './Validate-HashIOCs-DoD.ps1'
```

These checks cover input validation, cloud and tenant rejection, returned file
identity, missing results, retries, token refresh, CSV handling, and resume.
They also cover a missing CLI, failed authentication and exit codes, malformed
JSON and token metadata, expired and near expiry tokens, changed cloud or tenant,
read only CLI subcommands, no login or fallback, and credential output suppression.
Cloud Shell and managed identity account metadata fixtures exercise current
account token acquisition without `--tenant`. Wrong or missing token tenants,
wrong cloud or account tenant, and wrong tenant on refresh stop before the next
API request. The observed unsupported MSI audience response is tested as an
explicit credential safe failure, with no lookup or login fallback. On Windows,
local native command fixtures also verify exact CLI arguments, process exit
codes, and stderr suppression without launching Azure CLI. Passing success
fixtures is not live Cloud Shell or managed identity validation and does not
override the observed hosted credential restriction.
Passing synthetic checks does not establish live permissions or government
service availability. Validate a small approved input in your target environment
before a full batch.

## References

1. [Get file information API](https://learn.microsoft.com/defender-endpoint/api/get-file-information)
2. [File resource fields](https://learn.microsoft.com/defender-endpoint/api/files)
3. [MDE government API endpoints](https://learn.microsoft.com/defender-endpoint/gov#api)
4. [Get an MDE access token](https://learn.microsoft.com/defender-endpoint/api/exposed-apis-create-app-nativeapp)
5. [Original VT based bulk IOC workflow](../Bulk%20IOC%20Validation/README.md)
6. [Azure CLI interactive authentication and device code fallback](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)
7. [Azure CLI certificate service principal authentication](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-service-principal)
8. [Azure CLI token command and tenant limitations](https://learn.microsoft.com/cli/azure/account#az-account-get-access-token)
