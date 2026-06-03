# IOC Hash Validation

PowerShell script that checks file hash IOCs exported from Microsoft Defender for Endpoint (MDE) against VirusTotal (VT). It produces an Excel report showing which indicators are already covered by Microsoft Defender Antivirus (MDAV) so you can decide which ones to retire from MDE.

## What it does

For every SHA256, SHA1, or MD5 in your input file the script:

1. Calls `https://www.virustotal.com/api/v3/files/{hash}`.
2. Reads the aggregate verdict (`malicious`, `suspicious`, `harmless`, `undetected`, `reputation`, `last_analysis_date`).
3. Reads the Microsoft engine entry from `last_analysis_results.Microsoft` (category, signature name, engine name, engine version, engine update date, method).
4. Writes an `.xlsx` with three sheets: `Summary`, `Already Covered by MDAV/VT`, `All Hashes`.

The `OverallVerdict` column tells you the action:

| Verdict | Meaning |
| --- | --- |
| `MDAV-Malicious` or `MDAV-Suspicious` | Microsoft engine on VT flags it. Safe to remove from MDE, MDAV will catch it. |
| `VT-Malicious(n)` or `VT-Suspicious(n)` | Other AV vendors flag it but Microsoft does not. Keep in MDE. |
| `Clean` | No vendor flags it. Review whether the indicator is still needed. |
| `Unknown` | VT has no record. Keep in MDE. |

## Known limitation

VirusTotal does not return Microsoft's Security Intelligence (signature) version (the `1.x.x.x` value). To confirm the signature version actually deployed on an endpoint use one of:

- `Get-MpComputerStatus | Select-Object AntivirusSignatureVersion, AntivirusSignatureLastUpdated`
- Advanced Hunting: `DeviceEvents | where ActionType == "AntivirusDetection" | extend SigVer = tostring(parse_json(AdditionalFields).SecurityIntelligenceVersion)`
- <https://www.microsoft.com/wdsi/definitions>

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- A VirusTotal API key (free tier works; respect the 4 req/min limit by setting `-VtDelayMs 15000`)
- `ImportExcel` module (auto installed on first run)

## How to run

1. Export your file hash indicators from MDE: Settings, Endpoints, Indicators, File hashes, Export.
2. Drop the exported `.csv` or `.xlsx` into this folder next to `Validate-HashIOCs.ps1`.
3. Open PowerShell in this folder and run:

   ```powershell
   .\Validate-HashIOCs.ps1
   ```

   You'll be prompted for your VT API key (input is hidden). The script auto picks the newest non `Validated` CSV or XLSX in the folder.

4. When it finishes, `Hash_Validated_<timestamp>.xlsx` opens automatically.

### Optional parameters

| Parameter | Purpose |
| --- | --- |
| `-InputPath` | Explicit path to the input file |
| `-OutputPath` | Explicit path for the output `.xlsx` |
| `-VtApiKey` | Pass the key instead of being prompted (also reads `$env:VT_API_KEY`) |
| `-VtDelayMs` | Milliseconds to sleep between VT calls (use `15000` for the free tier) |

Example:

```powershell
.\Validate-HashIOCs.ps1 -InputPath .\Hash.csv -VtDelayMs 15000
```

## Input format

The script accepts the native MDE indicator export schema. It looks for these column names (case insensitive):

- `Indicator Value` (or `IndicatorValue`, `Hash`, `Sha256`, `Sha1`, `Md5`)
- `Indicator Type` (optional, auto detected from the hash length)

A sample is included as `Hash.sample.csv`.

## Output columns

| Column | Source |
| --- | --- |
| `IndicatorValue`, `IndicatorType` | Input |
| `VtStatus` | `Found`, `NotFound`, or error |
| `VtMalicious`, `VtSuspicious`, `VtHarmless`, `VtUndetected` | `last_analysis_stats` |
| `VtReputation`, `VtLastAnalysis` | `attributes` |
| `MdavCategory`, `MdavSignature`, `MdavEngineName`, `MdavEngineVersion`, `MdavEngineUpdateDate`, `MdavMethod` | `last_analysis_results.Microsoft` |
| `VtLink` | Direct VT GUI URL |
| `OverallVerdict` | See table above |

## Screenshots

