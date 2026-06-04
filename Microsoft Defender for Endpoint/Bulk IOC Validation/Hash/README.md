# Hash IOC Validation

PowerShell script that checks file hash IOCs exported from Microsoft Defender for Endpoint (MDE) against VirusTotal (VT). Output is an Excel file that flags the ones MDAV already detects so you can remove them from MDE.

## What it does

For every SHA256, SHA1, or MD5 in your input the script:

1. Calls `https://www.virustotal.com/api/v3/files/{hash}`.
2. Reads the aggregate verdict (`malicious`, `suspicious`, `harmless`, `undetected`, `reputation`, `last_analysis_date`).
3. Reads the Microsoft engine entry from `last_analysis_results.Microsoft`.
4. Writes an `.xlsx` with three sheets: `Summary`, `Already Covered by MDAV/VT`, `All Hashes`.

The `OverallVerdict` column tells you what to do:

| Verdict | Meaning |
|---|---|
| `MDAV-Malicious` or `MDAV-Suspicious` | Microsoft engine on VT flags it. Remove from MDE, MDAV will catch it. |
| `VT-Malicious(n)` or `VT-Suspicious(n)` | Other AVs flag it but Microsoft does not. Keep in MDE. |
| `Clean` | No vendor flags it. Decide whether the indicator is still needed. |
| `Unknown` | VT has no record. Keep in MDE. |

## Known limitation

VirusTotal does not return Microsoft's Security Intelligence signature version. To check the actual signature version on an endpoint:

- `Get-MpComputerStatus | Select-Object AntivirusSignatureVersion, AntivirusSignatureLastUpdated`
- Advanced Hunting: `DeviceEvents | where ActionType == "AntivirusDetection" | extend SigVer = tostring(parse_json(AdditionalFields).SecurityIntelligenceVersion)`
- <https://www.microsoft.com/wdsi/definitions>

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7.
- A VirusTotal API key. Free tier is fine, use `-VtDelayMs 15000` to stay under 4 req/min.
- `ImportExcel` module. Install it once before the first run, see the parent [Bulk IOC Validation README](../README.md#install-importexcel-once-before-you-run-anything).

## How to run

1. Export your file hash indicators from MDE: Settings, Endpoints, Indicators, File hashes, Export.
2. Drop the `.csv` or `.xlsx` into this folder next to `Validate-HashIOCs.ps1`.
3. Run PowerShell in this folder:

   ```powershell
   .\Validate-HashIOCs.ps1
   ```

   You will be prompted for your VT API key (input is hidden). The script picks the newest non `Validated` CSV or XLSX in the folder.

4. When it finishes, `Hash_Validated_<timestamp>.xlsx` opens.

### Optional parameters

| Parameter | Purpose |
|---|---|
| `-InputPath` | Path to the input file |
| `-OutputPath` | Path for the output `.xlsx` |
| `-VtApiKey` | Pass the key instead of being prompted (also reads `$env:VT_API_KEY`) |
| `-VtDelayMs` | Milliseconds to sleep between VT calls (use `15000` for free tier) |

Example:

```powershell
.\Validate-HashIOCs.ps1 -InputPath .\Hash.csv -VtDelayMs 15000
```

## Input format

Native MDE indicator export schema. Recognized column names (case insensitive):

- `Indicator Value` (or `IndicatorValue`, `Hash`, `Sha256`, `Sha1`, `Md5`)
- `Indicator Type` (optional, auto detected from the hash length)

`Hash.sample.csv` is included.

## Output columns

| Column | Source |
|---|---|
| `IndicatorValue`, `IndicatorType` | Input |
| `VtStatus` | `Found`, `NotFound`, or error |
| `VtMalicious`, `VtSuspicious`, `VtHarmless`, `VtUndetected` | `last_analysis_stats` |
| `VtReputation`, `VtLastAnalysis` | `attributes` |
| `MdavCategory`, `MdavSignature`, `MdavEngineName`, `MdavEngineVersion`, `MdavEngineUpdateDate`, `MdavMethod` | `last_analysis_results.Microsoft` |
| `VtLink` | Direct VT GUI URL |
| `OverallVerdict` | See table above |

## Screenshots

<img width="988" height="231" alt="image" src="https://github.com/user-attachments/assets/bdcacf97-7a34-4c89-b628-85760bcd370b" />

<img width="2277" height="201" alt="image" src="https://github.com/user-attachments/assets/5192b9ad-0cf5-4093-bdb6-7b4e2a6eccd7" />

<img width="2284" height="250" alt="image" src="https://github.com/user-attachments/assets/a50def35-4d96-43dc-af2e-ff389135c52f" />
