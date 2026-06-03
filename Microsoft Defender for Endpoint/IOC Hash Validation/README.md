# IOC Hash Validation

PowerShell script that checks file-hash IOCs exported from Microsoft Defender for Endpoint (MDE) against VirusTotal (VT) and produces an Excel report so you can decide which indicators are already covered by Microsoft Defender Antivirus (MDAV) and can be retired from MDE.

## What it does

For every SHA-256 / SHA-1 / MD5 in your input file the script:

1. Calls `https://www.virustotal.com/api/v3/files/{hash}`.
2. Pulls the aggregate verdict (`malicious`, `suspicious`, `harmless`, `undetected`, `reputation`, `last_analysis_date`).
3. Pulls the Microsoft engine entry from `last_analysis_results.Microsoft` (category, signature name, engine name, engine version, engine update date, method).
4. Writes an `.xlsx` with three sheets: **Summary**, **Already Covered by MDAV/VT**, **All Hashes**.

The **OverallVerdict** column tells you the action:

| Verdict | Meaning |
| --- | --- |
| `MDAV-Malicious` / `MDAV-Suspicious` | Microsoft engine on VT flags it — safe to remove from MDE, MDAV will catch it. |
| `VT-Malicious(n)` / `VT-Suspicious(n)` | Other AV vendors flag it but Microsoft does not — keep in MDE. |
| `Clean` | No vendor flags it — review whether the indicator is still needed. |
| `Unknown` | VT has no record — keep in MDE. |

## Known limitation

VirusTotal does **not** return Microsoft's Security Intelligence (signature) version (the `1.x.x.x` value). To confirm the signature version actually deployed on an endpoint use one of:

- `Get-MpComputerStatus | Select-Object AntivirusSignatureVersion, AntivirusSignatureLastUpdated`
- Advanced Hunting: `DeviceEvents | where ActionType == "AntivirusDetection" | extend SigVer = tostring(parse_json(AdditionalFields).SecurityIntelligenceVersion)`
- <https://www.microsoft.com/wdsi/definitions>

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- A VirusTotal API key (free tier works; respect the 4 req/min limit by setting `-VtDelayMs 15000`)
- `ImportExcel` module (auto-installed on first run)

## How to run

1. Export your file-hash indicators from MDE: **Settings → Endpoints → Indicators → File hashes → Export**.
2. Drop the exported `.csv` (or `.xlsx`) into this folder next to `Validate-HashIOCs.ps1`.
3. Open PowerShell in this folder and run:

   ```powershell
   .\Validate-HashIOCs.ps1
   ```

   You'll be prompted for your VT API key (input is hidden). The script auto-picks the newest non-`Validated` CSV/XLSX in the folder.

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

The script accepts the native MDE indicator export schema. It looks for these column names (case-insensitive):

- `Indicator Value` (or `IndicatorValue`, `Hash`, `Sha256`, `Sha1`, `Md5`)
- `Indicator Type` (optional — auto-detected from the hash length)

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
