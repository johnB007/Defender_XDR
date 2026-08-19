<#
.SYNOPSIS
    Generates controlled telemetry for the unauthorized AI workbook.
.DESCRIPTION
    Creates synthetic files and process activity, then sends header only web
    requests to selected AI services. No prompts, credentials, or file content
    are sent. Test artifacts are removed by default after activity is created.
.PARAMETER Generate
    Confirms that telemetry generation is authorized.
.PARAMETER ExpectedDeviceName
    Device name guard. The default permits execution only on device 324.
.PARAMETER AllowAnyDevice
    Overrides the device name guard.
.PARAMETER RequestCount
    Number of header requests sent to each selected service.
.PARAMETER IncludePersistence
    Briefly creates and removes a test Run value for persistence telemetry.
.PARAMETER KeepArtifacts
    Retains synthetic files after the run.
.PARAMETER ArtifactHoldSeconds
    Minimum time to retain synthetic files before default cleanup.
#>
[CmdletBinding()]
param(
    [switch]$Generate,
    [string]$ExpectedDeviceName = '324-UM-DEFCON30',
    [switch]$AllowAnyDevice,
    [ValidateRange(1, 10)]
    [int]$RequestCount = 2,
    [switch]$IncludePersistence,
    [switch]$KeepArtifacts,
    [ValidateRange(0, 60)]
    [int]$ArtifactHoldSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$device = $env:COMPUTERNAME
$utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

if (-not $Generate) {
    Write-Output ("Device: {0}  UTC: {1}" -f $device, $utc)
    Write-Output 'No telemetry was generated. Run with -Generate after authorization.'
    Write-Output 'Live Response example: run Invoke-AIWorkbookTelemetry.ps1 -parameters "-Generate"'
    exit 0
}

if (-not $AllowAnyDevice -and $device -ine $ExpectedDeviceName) {
    Write-Error ("Device guard stopped execution. Expected {0}, found {1}." -f $ExpectedDeviceName, $device)
    exit 2
}

$runId = [Guid]::NewGuid().ToString('N')
$root = Join-Path $env:ProgramData ("AIWorkbookTelemetryTest\{0}" -f $runId)
$secretDirectory = Join-Path $root 'secret'
$contextDirectory = Join-Path $root '.agents'
$reportPath = Join-Path $env:TEMP ("AIWorkbookTelemetry-{0}.json" -f $runId)
$runKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
$runValueName = 'AIWorkbookTelemetryTest'
$runValueCreated = $false
$results = New-Object System.Collections.Generic.List[object]

function Add-TestResult {
    param(
        [string]$Category,
        [string]$Action,
        [string]$Status,
        [string]$Detail
    )

    $script:results.Add([pscustomobject]@{
        TimeUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        Device = $script:device
        Category = $Category
        Action = $Action
        Status = $Status
        Detail = $Detail
    })
}

try {
    New-Item -ItemType Directory -Path $secretDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $contextDirectory -Force | Out-Null

    $contextPadding = 'X' * 8192
    $modelPadding = '0' * 1048576

    $syntheticFiles = @(
        [pscustomobject]@{ Path = (Join-Path $secretDirectory 'telemetry-test-secret.csv'); Content = "SyntheticId,Classification`r`n$runId,TestOnly"; Category = 'Exposure indicator' },
        [pscustomobject]@{ Path = (Join-Path $root 'ollama-telemetry-test.exe'); Content = 'Synthetic installer marker. Not executable.'; Category = 'Local AI installer' },
        [pscustomobject]@{ Path = (Join-Path $root 'telemetry-model.gguf'); Content = "Synthetic model marker. Not a model.`r`n$modelPadding"; Category = 'Local AI model' },
        [pscustomobject]@{ Path = (Join-Path $contextDirectory 'AGENTS.md'); Content = "Synthetic agent instruction marker.`r`n$contextPadding"; Category = 'Agent context' },
        [pscustomobject]@{ Path = (Join-Path $contextDirectory 'CLAUDE.md'); Content = "Synthetic Claude context marker.`r`n$contextPadding"; Category = 'Agent context' },
        [pscustomobject]@{ Path = (Join-Path $contextDirectory 'mcp.json'); Content = ('{"telemetryTest":true,"server":"none","padding":"' + $contextPadding + '"}'); Category = 'MCP context' }
    )

    foreach ($file in $syntheticFiles) {
        [System.IO.File]::WriteAllText($file.Path, $file.Content, [System.Text.Encoding]::UTF8)
        Add-TestResult -Category $file.Category -Action 'Create synthetic file' -Status 'Created' -Detail $file.Path
    }

    $cmdPath = Join-Path $env:WINDIR 'System32\cmd.exe'
    $cmdArguments = '/d /c echo mcp modelcontextprotocol telemetry test openclaw aider claude-code'
    $cmdProcess = Start-Process -FilePath $cmdPath -ArgumentList $cmdArguments -WindowStyle Hidden -PassThru -Wait
    Add-TestResult -Category 'Agent and MCP' -Action 'Create process event' -Status ("ExitCode {0}" -f $cmdProcess.ExitCode) -Detail $cmdArguments

    if ($IncludePersistence) {
        $persistenceTarget = Join-Path $root 'ollama-telemetry-test.exe'
        New-ItemProperty -Path $runKey -Name $runValueName -Value $persistenceTarget -PropertyType String -Force | Out-Null
        $runValueCreated = $true
        Add-TestResult -Category 'Persistence' -Action 'Create test Run value' -Status 'Created' -Detail $persistenceTarget
        Remove-ItemProperty -Path $runKey -Name $runValueName -Force
        $runValueCreated = $false
        Add-TestResult -Category 'Persistence' -Action 'Remove test Run value' -Status 'Removed' -Detail $runValueName
    }

    $curlPath = Join-Path $env:WINDIR 'System32\curl.exe'
    if (Test-Path -LiteralPath $curlPath) {
        $targets = @(
            'https://chatgpt.com/',
            'https://claude.ai/',
            'https://perplexity.ai/',
            'https://copilot.microsoft.com/'
        )

        foreach ($target in $targets) {
            for ($request = 1; $request -le $RequestCount; $request++) {
                $curlArguments = @(
                    '--head',
                    '--silent',
                    '--show-error',
                    '--max-time', '12',
                    '--output', 'NUL',
                    '--user-agent', 'AIWorkbookTelemetryValidation/1.0',
                    $target
                )

                $curlProcess = Start-Process -FilePath $curlPath -ArgumentList $curlArguments -WindowStyle Hidden -PassThru -Wait
                $status = if ($curlProcess.ExitCode -eq 0) { 'Connected' } else { "ExitCode {0}" -f $curlProcess.ExitCode }
                Add-TestResult -Category 'Network and API' -Action 'Header request' -Status $status -Detail $target
            }
        }
    }
    else {
        Add-TestResult -Category 'Network and API' -Action 'Header request' -Status 'Skipped' -Detail 'curl.exe was not found.'
    }

    $edgePaths = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
    )
    $edgePath = $edgePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if ($edgePath) {
        $edgeProfile = Join-Path $root 'edge-profile'
        $edgeOutput = Join-Path $root 'edge-output.txt'
        $edgeError = Join-Path $root 'edge-error.txt'
        $edgeArguments = @(
            '--headless=new',
            '--disable-gpu',
            '--disable-extensions',
            '--no-first-run',
            ("--user-data-dir={0}" -f $edgeProfile),
            '--dump-dom',
            'https://chatgpt.com/'
        )

        $edgeProcess = Start-Process -FilePath $edgePath -ArgumentList $edgeArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $edgeOutput -RedirectStandardError $edgeError
        if (-not $edgeProcess.WaitForExit(20000)) {
            & (Join-Path $env:WINDIR 'System32\taskkill.exe') /PID $edgeProcess.Id /T /F | Out-Null
            Add-TestResult -Category 'Browser AI' -Action 'Headless Edge request' -Status 'Stopped after 20 seconds' -Detail 'https://chatgpt.com/'
        }
        else {
            Add-TestResult -Category 'Browser AI' -Action 'Headless Edge request' -Status ("ExitCode {0}" -f $edgeProcess.ExitCode) -Detail 'https://chatgpt.com/'
        }
    }
    else {
        Add-TestResult -Category 'Browser AI' -Action 'Headless Edge request' -Status 'Skipped' -Detail 'Microsoft Edge was not found.'
    }

    if (-not $KeepArtifacts -and $ArtifactHoldSeconds -gt 0) {
        Write-Output ("Holding synthetic artifacts for {0} seconds before cleanup." -f $ArtifactHoldSeconds)
        Start-Sleep -Seconds $ArtifactHoldSeconds
    }

    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8

    Write-Output ("Device: {0}  UTC: {1}" -f $device, $utc)
    Write-Output ("Run ID: {0}" -f $runId)
    Write-Output ("Events requested: {0}" -f $results.Count)
    $results | Select-Object Category, Action, Status, Detail | Format-Table -AutoSize | Out-String | Write-Output
    Write-Output ("Report: {0}" -f $reportPath)
    Write-Output 'Allow up to 15 minutes for MDE telemetry ingestion, then filter the workbook to this device.'
    exit 0
}
catch {
    Write-Error ("Telemetry generation failed: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if ($runValueCreated) {
        Remove-ItemProperty -Path $runKey -Name $runValueName -Force -ErrorAction SilentlyContinue
    }

    if (-not $KeepArtifacts -and (Test-Path -LiteralPath $root)) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}