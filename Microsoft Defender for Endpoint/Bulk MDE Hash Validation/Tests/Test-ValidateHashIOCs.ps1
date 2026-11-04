#Requires -Version 7.0
<#
.SYNOPSIS
    Run synthetic checks without authentication or network requests.
#>
[CmdletBinding()]
param(
    [string]$ScriptPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Validate-HashIOCs-DoD.ps1'),
    [ValidateSet('AzureCloud', 'AzureUSGovernment')]
    [string]$AzureEnvironment = 'AzureUSGovernment',
    [string]$ApiBaseUri = 'https://api-gov.securitycenter.microsoft.us',
    [string]$TokenResource = 'https://api-gov.securitycenter.microsoft.us'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "MdeHashTests-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $testRoot | Out-Null
$tenant = '11111111-1111-1111-1111-111111111111'
$sha256 = 'a' * 64
$sha1 = 'b' * 40
$md5 = 'c' * 32
$cases = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Fixture {
    param(
        [string]$Name,
        [string[]]$Lines,
        [object[]]$Responses = @(),
        [string]$Environment = $AzureEnvironment,
        [string]$ContextTenant = $tenant,
        [switch]$Resume,
        [switch]$InsecureToken,
        [switch]$ExpiredToken
    )
    $folder = Join-Path $testRoot $Name
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $inputCsv = Join-Path $folder 'input.csv'
    $report = Join-Path $folder 'report.csv'
    if ($Lines) { Set-Content -LiteralPath $inputCsv -Value $Lines -Encoding utf8 }
    $state = @{
        Requests = [Collections.Generic.List[object]]::new()
        Sleeps = [Collections.Generic.List[double]]::new()
        TokenCalls = 0
        Warnings = @()
    }

    # These functions shadow every module, identity, network, and sleep operation.
    function Import-Module { param($Name, $MinimumVersion, $ErrorAction) }
    function Get-AzContext {
        param($ErrorAction)
        [pscustomobject]@{
            Tenant = [pscustomobject]@{ Id = $ContextTenant }
            Environment = [pscustomobject]@{ Name = $Environment }
        }
    }
    function Get-AzAccessToken {
        param($ResourceUrl, $TenantId, [switch]$AsSecureString, $ErrorAction)
        Assert-True ($ResourceUrl -eq $TokenResource) 'Wrong token audience.'
        Assert-True ($TenantId -eq $tenant -and $AsSecureString) 'Wrong tenant or insecure token request.'
        $state.TokenCalls++
        $secureToken = [securestring]::new()
        $secureToken.AppendChar('x')
        [pscustomobject]@{
            Token = if ($InsecureToken) { 'synthetic' } else { $secureToken }
            ExpiresOn = if ($ExpiredToken) {
                [datetimeoffset]::UtcNow.AddMinutes(-1)
            } else {
                [datetimeoffset]::UtcNow.AddHours(1)
            }
        }
    }
    function Start-Sleep {
        param([double]$Seconds, [double]$Milliseconds)
        $state.Sleeps.Add($Seconds + $Milliseconds / 1000)
    }
    function Invoke-RestMethod {
        param($Method, $Uri, $Authentication, $Token, $MaximumRedirection, $TimeoutSec,
            [switch]$SkipHttpErrorCheck, $StatusCodeVariable, $ResponseHeadersVariable, $ErrorAction)
        Assert-True ($Method -eq 'Get') 'Unexpected HTTP method.'
        Assert-True ($Uri -match ('^' + [regex]::Escape($ApiBaseUri) + '/api/files/[a-f0-9]{40}([a-f0-9]{24})?$')) 'Unexpected destination.'
        Assert-True ($Authentication -eq 'Bearer' -and $Token -is [securestring]) 'Insecure authentication.'
        Assert-True ($MaximumRedirection -eq 0 -and $TimeoutSec -eq 60 -and $SkipHttpErrorCheck) 'Unsafe HTTP options.'
        $responseIndex = $state.Requests.Count
        $state.Requests.Add([pscustomobject]@{ Uri = $Uri })
        if ($responseIndex -ge $Responses.Count) { throw 'Unexpected request beyond fixture responses.' }
        $fixture = $Responses[$responseIndex]
        if ($fixture.ContainsKey('Throw')) { throw 'Synthetic transport failure.' }
        Set-Variable -Name $StatusCodeVariable -Value $fixture.Status -Scope 1
        $headers = if ($fixture.ContainsKey('Headers')) { $fixture.Headers } else { @{} }
        Set-Variable -Name $ResponseHeadersVariable -Value $headers -Scope 1
        if ($fixture.ContainsKey('File')) { return $fixture.File }
        return [pscustomobject]@{}
    }
    $failure = $null
    try {
        & $scriptPath -InputPath $inputCsv -OutputPath $report -TenantId $tenant -Resume:$Resume `
            -WarningVariable capturedWarnings -WarningAction SilentlyContinue | Out-Null
        $state.Warnings = @($capturedWarnings)
    } catch {
        $failure = $_.Exception.Message
    }
    [pscustomobject]@{
        State = $state
        Failure = $failure
        Report = if (Test-Path -LiteralPath $report) { @(Import-Csv -LiteralPath $report) } else { @() }
        InputPath = $inputCsv
        ReportPath = $report
    }
}

try {
    $file = [pscustomobject]@{
        sha256 = $sha256; sha1 = $sha1; determinationType = 'Malware'
        determinationValue = 'Synthetic.Test'; globalPrevalence = 0
        isPeFile = $false; isValidCertificate = $false; signer = '=synthetic'
    }
    $ok = @{ Status = 200; File = $file }
    $r = Invoke-Fixture -Name 'success' -Lines @('Indicator Value,Indicator Type', "$sha256,FileSha256", "$sha1,FileSha1") -Responses @($ok, $ok)
    Assert-True ($null -eq $r.Failure -and $r.Report.Count -eq 2) 'Valid hashes failed.'
    Assert-True ($r.State.TokenCalls -eq 1 -and $r.State.Requests.Count -eq 2) 'Token was not cached.'
    Assert-True ($r.Report[0].DeterminationType -eq 'Malware' -and $r.Report[0].ThreatName -eq 'Synthetic.Test') 'Verdict not preserved.'
    Assert-True ($r.Report[0].GlobalPrevalence -eq '0' -and $r.Report[0].IsPeFile -eq 'False' -and $r.Report[0].IsValidCertificate -eq 'False') 'Zero or false fields were lost.'
    Assert-True ($r.Report[0].Signer -eq "'=synthetic") 'CSV formula protection failed.'
    Assert-True (@($r.State.Sleeps | Where-Object { $_ -gt 2.0 }).Count -gt 0) 'Requests were not paced.'
    $cases++

    $r = Invoke-Fixture -Name 'invalid' -Lines @('Indicator Value,Indicator Type', "$md5,FileMd5", 'not-a-hash,', ",", "$sha1,FileSha256")
    Assert-True ($r.State.Requests.Count -eq 0 -and $r.State.TokenCalls -eq 0) 'Invalid values triggered a request.'
    Assert-True ($r.Report.Count -eq 4 -and $r.Report[0].LookupStatus -eq 'Unsupported' -and $null -ne $r.Failure) 'Invalid rows were not reported.'
    $cases++

    $wrongEnvironment = if ($AzureEnvironment -eq 'AzureCloud') { 'AzureUSGovernment' } else { 'AzureCloud' }
    foreach ($boundary in @(
        @{ Name = 'wrongcloud'; Environment = $wrongEnvironment; Tenant = $tenant },
        @{ Name = 'wrongtenant'; Environment = $AzureEnvironment; Tenant = '22222222-2222-2222-2222-222222222222' }
    )) {
        $r = Invoke-Fixture -Name $boundary.Name -Lines @('Hash', $sha256) -Environment $boundary.Environment -ContextTenant $boundary.Tenant
        Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.State.TokenCalls -eq 0) 'Authentication boundary was not enforced.'
        $cases++
    }

    $r = Invoke-Fixture -Name 'missing' -Lines @('Hash', $sha256) -Responses @(@{ Status = 404 })
    Assert-True ($null -eq $r.Failure -and $r.Report[0].LookupStatus -eq 'NotFound' -and -not $r.Report[0].DeterminationType) '404 became a verdict.'
    $cases++

    $r = Invoke-Fixture -Name 'sparse' -Lines @('Hash', $sha256) -Responses @(@{ Status = 200; File = [pscustomobject]@{ sha256 = $sha256 } })
    Assert-True ($null -eq $r.Failure -and -not $r.Report[0].DeterminationType -and -not $r.Report[0].IsPeFile) 'Missing fields became negative values.'
    $cases++

    foreach ($status in @(429, 503)) {
        $r = Invoke-Fixture -Name "retry$status" -Lines @('Hash', $sha256) -Responses @(@{ Status = $status; Headers = @{ 'Retry-After' = @('75') } }, $ok)
        Assert-True ($null -eq $r.Failure -and $r.State.Requests.Count -eq 2 -and $r.State.Sleeps.Contains(75)) 'Retry header was not respected.'
        $cases++
    }
    $dateDelay = [datetimeoffset]::UtcNow.AddMinutes(2).ToString('r')
    $r = Invoke-Fixture -Name 'retrydate' -Lines @('Hash', $sha256) -Responses @(@{ Status = 429; Headers = @{ 'Retry-After' = $dateDelay } }, $ok)
    Assert-True ($null -eq $r.Failure -and @($r.State.Sleeps | Where-Object { $_ -ge 110 }).Count -eq 1) 'Retry date was not respected.'
    $cases++

    $r = Invoke-Fixture -Name 'bounded' -Lines @('Hash', $sha256) -Responses (@(@{ Status = 429 }) * 6)
    Assert-True ($r.State.Requests.Count -eq 6 -and $r.Report[0].LookupStatus -eq 'RateLimited' -and $null -ne $r.Failure) 'Retries were not bounded.'
    $cases++

    $r = Invoke-Fixture -Name 'transport' -Lines @('Hash', $sha256) -Responses @(@{ Throw = $true }, $ok)
    Assert-True ($null -eq $r.Failure -and $r.State.Requests.Count -eq 2) 'Transport retry failed.'
    $cases++

    $r = Invoke-Fixture -Name 'transportexhausted' -Lines @('Hash', $sha256) -Responses (@(@{ Throw = $true }) * 6)
    Assert-True ($null -ne $r.Failure -and $r.Report[0].LookupStatus -eq 'RequestFailed' -and $r.State.Requests.Count -eq 6) 'Exhausted transport failures were not surfaced.'
    $cases++

    $r = Invoke-Fixture -Name 'refresh' -Lines @('Hash', $sha256) -Responses @(@{ Status = 401 }, $ok)
    Assert-True ($null -eq $r.Failure -and $r.State.TokenCalls -eq 2) 'Token rejection was not refreshed once.'
    $cases++

    foreach ($status in @(401, 403)) {
        $r = Invoke-Fixture -Name "stop$status" -Lines @('Hash', $sha256, $sha1) -Responses @(@{ Status = $status }, @{ Status = $status })
        Assert-True ($null -ne $r.Failure -and $r.Report.Count -eq 1 -and $r.State.Requests.Count -le 2) 'Access failure did not stop safely.'
        $cases++
    }
    $r = Invoke-Fixture -Name 'mismatch' -Lines @('Hash', $sha256, $sha1) -Responses @(@{ Status = 200; File = [pscustomobject]@{ sha256 = ('d' * 64) } })
    Assert-True ($null -ne $r.Failure -and $r.Report[0].LookupStatus -eq 'ResponseMismatch' -and $r.State.Requests.Count -eq 1) 'Wrong file response was accepted.'
    $cases++

    $r = Invoke-Fixture -Name 'success' -Resume
    Assert-True ($null -eq $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 2) 'Resume repeated completed requests.'
    $cases++
    $r = Invoke-Fixture -Name 'success'
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 2) 'Existing report was overwritten.'
    $cases++
    $r = Invoke-Fixture -Name 'success' -Resume -Lines @('Hash', $sha1)
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0) 'Changed input was accepted for resume.'
    $cases++

    $r = Invoke-Fixture -Name 'partial' -Lines @('Hash', $sha256, $sha1) -Responses @(@{ Status = 403 })
    $r = Invoke-Fixture -Name 'partial' -Resume -Responses @($ok)
    Assert-True ($null -ne $r.Failure -and $r.Report.Count -eq 2 -and $r.State.Requests.Count -eq 1 -and $r.Report[1].LookupStatus -eq 'Found') 'Partial resume lost a prior failure or repeated a row.'
    $cases++

    $r = Invoke-Fixture -Name 'header' -Lines @('WrongColumn', $sha256)
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0) 'Missing hash header was accepted.'
    $cases++
    $r = Invoke-Fixture -Name 'empty' -Lines @('Hash')
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0) 'Empty CSV was accepted.'
    $cases++
    $r = Invoke-Fixture -Name 'uppercase' -Lines @('indicatorvalue', $sha256.ToUpperInvariant()) -Responses @($ok)
    Assert-True ($null -eq $r.Failure -and $r.Report[0].IndicatorValue -ceq $sha256) 'Header or hash normalization failed.'
    $cases++
    $r = Invoke-Fixture -Name 'insecure' -Lines @('Hash', $sha256) -InsecureToken
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0) 'Plain token was accepted.'
    $cases++
    $r = Invoke-Fixture -Name 'expired' -Lines @('Hash', $sha256) -ExpiredToken
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0) 'Expired token was accepted.'
    $cases++
    Write-Output "Passed: $cases synthetic cases. No authentication or network requests."
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
