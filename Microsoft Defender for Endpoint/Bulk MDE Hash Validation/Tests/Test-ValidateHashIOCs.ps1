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
        [string]$CliCase = 'Normal'
    )
    $folder = Join-Path $testRoot $Name
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $inputCsv = Join-Path $folder 'input.csv'
    $report = Join-Path $folder 'report.csv'
    if ($Lines) { Set-Content -LiteralPath $inputCsv -Value $Lines -Encoding utf8 }
    # A local native shim also checks real process exit codes and stderr handling.
    # It never invokes Azure CLI, reads its cache, or performs network operations.
    if ($CliCase -like 'Native*') {
        $nativeShim = Join-Path $folder 'synthetic-az.cmd'
        $epoch = [datetimeoffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()
        $shimLines = @('@echo off', 'echo SYNTHETIC-CREDENTIAL-MARKER 1>&2')
        if ($CliCase -eq 'NativeFailure') {
            $shimLines += @('echo {"accessToken":"SYNTHETIC-CREDENTIAL-MARKER"}', 'exit /b 19')
        } else {
            $nativeCloud = if ($CliCase -eq 'NativeCloudShellWrongCloud') { 'WrongCloud' } else { $Environment }
            $nativeAccount = @{
                tenantId = $ContextTenant; environmentName = $Environment
                user = @{ name = 'synthetic'; type = 'cloudShell' }
            } | ConvertTo-Json -Compress
            $nativeToken = @{
                tenant = $tenant; tokenType = 'Bearer'
                accessToken = 'SYNTHETIC-CREDENTIAL-MARKER'; expires_on = $epoch
            }
            if ($CliCase -eq 'NativeCloudShellWrongTenant') {
                $nativeToken.tenant = '22222222-2222-2222-2222-222222222222'
            }
            if ($CliCase -eq 'NativeCloudShellMissingTenant') { $nativeToken.Remove('tenant') }
            $shimLines += @(
                'if "%~1 %~2"=="cloud show" (',
                'if not "%*"=="cloud show --output json --only-show-errors" exit /b 19',
                ('echo {"name":"' + $nativeCloud + '"}'), 'exit /b 0', ')',
                'if "%~1 %~2"=="account show" (',
                'if not "%*"=="account show --output json --only-show-errors" exit /b 19',
                ('echo ' + $nativeAccount),
                'exit /b 0', ')',
                'if "%~1 %~2"=="account get-access-token" (',
                ('if not "%*"=="account get-access-token --resource ' + $TokenResource + ' --output json --only-show-errors" exit /b 19'),
                $(if ($CliCase -eq 'NativeCloudShellUnsupportedAudience') {
                    'echo Audience ' + $TokenResource + ' is not a supported MSI token audience. 1>&2'
                    'exit /b 19'
                }),
                ('echo ' + ($nativeToken | ConvertTo-Json -Compress)),
                'exit /b 0', ')', 'exit /b 19'
            )
        }
        Set-Content -LiteralPath $nativeShim -Value $shimLines -Encoding ascii
    }
    $state = @{
        Requests = [Collections.Generic.List[object]]::new()
        Sleeps = [Collections.Generic.List[double]]::new()
        TokenCalls = 0
        CliCalls = [Collections.Generic.List[string]]::new()
        Output = [Collections.Generic.List[string]]::new()
        Warnings = @()
    }

    # Shadow CLI discovery and invocation: never use the installed CLI or its cache.
    function Get-Command {
        param($Name, $CommandType, $ErrorAction)
        Assert-True ($Name -eq 'az' -and $CommandType -eq 'Application') 'Unexpected command discovery.'
        if ($CliCase -eq 'MissingCli') { throw 'Synthetic missing CLI.' }
        if ($CliCase -like 'Native*') { return $nativeShim }
        return 'az'
    }
    function az {
        $command = $args -join ' '
        $state.CliCalls.Add($command)
        Set-Variable -Name LASTEXITCODE -Value 0 -Scope 1
        $allowed = @(
            'cloud show --output json --only-show-errors',
            'account show --output json --only-show-errors',
            "account get-access-token --resource $TokenResource --output json --only-show-errors"
        )
        Assert-True ($command -in $allowed) 'CLI attempted a mutation, login, fallback, or incorrect token request.'
        if ($CliCase -eq 'CloudShellUnsupportedAudience' -and $args[1] -eq 'get-access-token') {
            Set-Variable -Name LASTEXITCODE -Value 1 -Scope 1
            Write-Error "Audience $TokenResource is not a supported MSI token audience. SYNTHETIC-CREDENTIAL-MARKER" -ErrorAction Continue
            return '{"accessToken":"SYNTHETIC-CREDENTIAL-MARKER"}'
        }
        if ($CliCase -eq 'CliFailure' -or ($CliCase -eq 'TokenFailure' -and $args[1] -eq 'get-access-token')) {
            Set-Variable -Name LASTEXITCODE -Value 1 -Scope 1
            Write-Error 'SYNTHETIC-CREDENTIAL-MARKER' -ErrorAction Continue
            return '{"accessToken":"SYNTHETIC-CREDENTIAL-MARKER"}'
        }
        if ($args[0] -eq 'cloud') {
            if ($CliCase -eq 'MalformedCloud') { return '{SYNTHETIC-CREDENTIAL-MARKER' }
            if ($CliCase -eq 'CloudShape') { return '[]' }
            $cloudName = if (($CliCase -eq 'CloudChanged' -and $state.Requests.Count -gt 0) -or
                $CliCase -eq 'CloudShellWrongCloud') { 'ChangedCloud' } else { $Environment }
            return (@{ name = $cloudName } | ConvertTo-Json -Compress)
        }
        if ($args[1] -eq 'show') {
            if ($CliCase -eq 'AccountShape') { return '{"tenantId":null}' }
            $activeTenant = if (($CliCase -eq 'TenantChanged' -and $state.Requests.Count -gt 0) -or
                $CliCase -eq 'CloudShellWrongAccountTenant') { '22222222-2222-2222-2222-222222222222' } else { $ContextTenant }
            $accountCloud = if ($CliCase -eq 'AccountCloud') { 'WrongCloud' } else { $Environment }
            $user = if ($CliCase -like 'CloudShell*') {
                @{ name = 'synthetic'; type = 'cloudShell' }
            } elseif ($CliCase -eq 'ManagedIdentity') {
                @{ name = 'systemAssignedIdentity'; type = 'servicePrincipal' }
            } else {
                @{ name = 'synthetic'; type = 'user' }
            }
            return (@{ tenantId = $activeTenant; environmentName = $accountCloud; user = $user } | ConvertTo-Json -Compress)
        }
        $state.TokenCalls++
        if ($CliCase -eq 'MalformedToken') { return '{SYNTHETIC-CREDENTIAL-MARKER' }
        if ($CliCase -eq 'TokenShape') { return '["SYNTHETIC-CREDENTIAL-MARKER"]' }
        $expiry = [datetimeoffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()
        if ($CliCase -eq 'ExpiredToken') { $expiry = [datetimeoffset]::UtcNow.AddMinutes(-1).ToUnixTimeSeconds() }
        if ($CliCase -eq 'NearExpiry' -and $state.TokenCalls -eq 1) { $expiry = [datetimeoffset]::UtcNow.AddMinutes(2).ToUnixTimeSeconds() }
        $token = @{
            accessToken = 'SYNTHETIC-CREDENTIAL-MARKER'; tokenType = 'Bearer'; tenant = $tenant
            expires_on = $expiry
            expiresOn = 'INVALID LOCALE DATE: MUST NOT BE USED'
        }
        switch ($CliCase) {
            'TokenTenant' { $token.tenant = '22222222-2222-2222-2222-222222222222' }
            'CloudShellWrongTokenTenant' { $token.tenant = '22222222-2222-2222-2222-222222222222' }
            'CloudShellMissingTokenTenant' { $token.Remove('tenant') }
            'CloudShellRefreshWrongTenant' {
                if ($state.TokenCalls -gt 1) { $token.tenant = '22222222-2222-2222-2222-222222222222' }
            }
            'TokenTenantArray' { $token.tenant = @($tenant) }
            'MissingTenant' { $token.Remove('tenant') }
            'MissingToken' { $token.Remove('accessToken') }
            'EmptyToken' { $token.accessToken = ' ' }
            'TokenObject' { $token.accessToken = @{ value = 'SYNTHETIC-CREDENTIAL-MARKER' } }
            'TokenType' { $token.tokenType = 'Unknown' }
            'TokenTypeArray' { $token.tokenType = @('Bearer') }
            'MissingExpiry' { $token.Remove('expires_on') }
            'MalformedExpiry' { $token.expires_on = 'tomorrow' }
            'FractionalExpiry' { $token.expires_on = 123.5 }
            'ExpiryArray' { $token.expires_on = @($expiry) }
            'ExpiryOverflow' { $token.expires_on = '9999999999999999999999999999999' }
            'ExpiryRange' { $token.expires_on = [long]::MaxValue }
            'RefreshFailure' {
                if ($state.TokenCalls -gt 1) {
                    Set-Variable -Name LASTEXITCODE -Value 1 -Scope 1
                    Write-Error 'SYNTHETIC-CREDENTIAL-MARKER' -ErrorAction Continue
                    return '{"accessToken":"SYNTHETIC-CREDENTIAL-MARKER"}'
                }
            }
        }
        return ($token | ConvertTo-Json -Compress)
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
        & $scriptPath -InputPath $inputCsv -OutputPath $report -TenantId $tenant -Resume:$Resume *>&1 |
            ForEach-Object { $state.Output.Add([string]$_) }
    } catch {
        $failure = $_.Exception.Message
    }
    $reportText = if (Test-Path -LiteralPath $report) { Get-Content -Raw -LiteralPath $report } else { '' }
    Assert-True (($state.Output -join "`n") -notmatch 'SYNTHETIC-CREDENTIAL-MARKER' -and
        $failure -notmatch 'SYNTHETIC-CREDENTIAL-MARKER' -and $reportText -notmatch 'SYNTHETIC-CREDENTIAL-MARKER') 'Credential text escaped to output, an error, or the report.'
    Assert-True (@($state.CliCalls | Where-Object { $_ -notmatch '^(cloud show|account show|account get-access-token) ' }).Count -eq 0) 'Non read only CLI call.'
    $allowedCalls = @('cloud show --output json --only-show-errors',
        'account show --output json --only-show-errors',
        "account get-access-token --resource $TokenResource --output json --only-show-errors")
    Assert-True (@($state.CliCalls | Where-Object { $_ -notin $allowedCalls }).Count -eq 0) 'Unexpected CLI arguments, tenant selection, login, or fallback.'
    [pscustomobject]@{
        State = $state
        Failure = $failure
        Report = @(if (Test-Path -LiteralPath $report) { Import-Csv -LiteralPath $report })
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
    foreach ($scenario in @('MissingCli', 'CliFailure', 'TokenFailure', 'MalformedCloud', 'CloudShape',
        'AccountShape', 'AccountCloud', 'MalformedToken', 'TokenShape', 'TokenTenant', 'TokenTenantArray', 'MissingTenant',
        'MissingToken', 'EmptyToken', 'TokenObject', 'TokenType', 'MissingExpiry', 'MalformedExpiry',
        'FractionalExpiry', 'TokenTypeArray', 'ExpiryArray', 'ExpiryOverflow', 'ExpiryRange', 'ExpiredToken')) {
        $r = Invoke-Fixture -Name $scenario -Lines @('Hash', $sha256) -CliCase $scenario
        Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 0) "CLI boundary failed: $scenario."
        $cases++
    }
    foreach ($scenario in @('CloudShell', 'ManagedIdentity')) {
        $r = Invoke-Fixture -Name $scenario -Lines @('Hash', $sha256) -CliCase $scenario -Responses @($ok)
        Assert-True ($null -eq $r.Failure -and $r.State.TokenCalls -eq 1 -and $r.Report[0].LookupStatus -eq 'Found') "Current account session rejected: $scenario."
        $cases++
    }
    foreach ($scenario in @('CloudShellWrongTokenTenant', 'CloudShellMissingTokenTenant',
        'CloudShellWrongCloud', 'CloudShellWrongAccountTenant')) {
        $r = Invoke-Fixture -Name $scenario -Lines @('Hash', $sha256) -CliCase $scenario
        Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 0) "Cloud Shell boundary failed: $scenario."
        if ($scenario -eq 'CloudShellMissingTokenTenant') {
            Assert-True ($r.Failure -match 'no usable tenant metadata') 'Missing token tenant limitation was not explicit.'
        }
        $cases++
    }
    $r = Invoke-Fixture -Name 'CloudShellRefresh' -Lines @('Hash', $sha256) -CliCase CloudShellRefresh -Responses @(@{ Status = 401 }, $ok)
    Assert-True ($null -eq $r.Failure -and $r.State.TokenCalls -eq 2 -and $r.Report[0].LookupStatus -eq 'Found') 'Cloud Shell current account refresh failed.'
    $cases++
    $r = Invoke-Fixture -Name 'CloudShellRefreshWrongTenant' -Lines @('Hash', $sha256) -CliCase CloudShellRefreshWrongTenant -Responses @(@{ Status = 401 }, $ok)
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 1 -and $r.Report.Count -eq 0 -and $r.Failure -match 'different tenant') 'Wrong tenant token on Cloud Shell refresh was accepted.'
    $cases++
    $r = Invoke-Fixture -Name 'CloudShellUnsupportedAudience' -Lines @('Hash', $sha256) -CliCase CloudShellUnsupportedAudience
    Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 0 -and
        $r.Failure.Contains("Audience $TokenResource is not a supported MSI token audience.")) 'Cloud Shell MSI audience rejection was not surfaced safely.'
    $cases++
    if ($IsWindows) {
        $r = Invoke-Fixture -Name 'NativeFailure' -Lines @('Hash', $sha256) -CliCase NativeFailure
        Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 0) 'Native CLI failure was accepted or exposed credentials.'
        $cases++
        $r = Invoke-Fixture -Name 'NativeSuccess' -Lines @('Hash', $sha256) -CliCase NativeSuccess -Responses @($ok)
        Assert-True ($null -eq $r.Failure -and $r.State.Requests.Count -eq 1 -and $r.Report[0].LookupStatus -eq 'Found') 'Native CLI success failed or exposed credentials.'
        $cases++
        $r = Invoke-Fixture -Name 'NativeCloudShell' -Lines @('Hash', $sha256) -CliCase NativeCloudShell -Responses @($ok)
        Assert-True ($null -eq $r.Failure -and $r.Report[0].LookupStatus -eq 'Found') 'Native Cloud Shell fixture failed without --tenant.'
        $cases++
        foreach ($scenario in @('NativeCloudShellWrongTenant', 'NativeCloudShellMissingTenant', 'NativeCloudShellWrongCloud')) {
            $r = Invoke-Fixture -Name $scenario -Lines @('Hash', $sha256) -CliCase $scenario
            Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 0) "Native Cloud Shell boundary failed: $scenario."
            $cases++
        }
        $r = Invoke-Fixture -Name 'NativeCloudShellUnsupportedAudience' -Lines @('Hash', $sha256) -CliCase NativeCloudShellUnsupportedAudience
        Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq 0 -and $r.Report.Count -eq 0 -and
            $r.Failure.Contains("Audience $TokenResource is not a supported MSI token audience.")) 'Native Cloud Shell MSI audience rejection was not surfaced safely.'
        $cases++
    }
    $r = Invoke-Fixture -Name 'NearExpiry' -Lines @('Hash', $sha256, $sha1) -Responses @($ok, $ok) -CliCase NearExpiry
    Assert-True ($null -eq $r.Failure -and $r.State.TokenCalls -eq 2) 'Near expiry token was not refreshed.'
    $cases++
    foreach ($scenario in @('CloudChanged', 'TenantChanged', 'RefreshFailure')) {
        $r = Invoke-Fixture -Name $scenario -Lines @('Hash', $sha256, $sha1) -Responses @($ok, @{ Status = 401 }, $ok) -CliCase $scenario
        $expectedRequests = if ($scenario -eq 'RefreshFailure') { 2 } else { 1 }
        Assert-True ($null -ne $r.Failure -and $r.State.Requests.Count -eq $expectedRequests -and $r.Report.Count -eq 1) "Refresh boundary failed: $scenario."
        $cases++
    }
    $source = Get-Content -Raw -LiteralPath $ScriptPath
    Assert-True ($source -notmatch '(?im)^\s*(Import-Module|Connect-AzAccount|Get-AzContext|Get-AzAccessToken)\b' -and
        $source -notmatch '(?i)--use-device-code|\baz\s+(login|configure|config|logout)|\bcloud[''"]?\s*,?\s*[''"]set') 'Legacy identity dependency or automatic login/configuration found.'
    $cases++
    Write-Output "Passed: $cases synthetic cases. No authentication or network requests."
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
