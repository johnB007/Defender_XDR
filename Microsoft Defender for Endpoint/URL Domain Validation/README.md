# URL / Domain IOC Validation

PowerShell script that validates URL and Domain IOCs exported from Microsoft Defender for Endpoint (MDE) by detonating each one on a lab host running Microsoft Defender Antivirus (MDAV), Network Protection (NP), and SmartScreen. It reads the local Defender event logs and reports which indicators are already blocked, so you can decide which ones to retire from MDE.

## What it does

For every Url, DomainName, or IpAddress row in your MDE export the script:

1. Resolves DNS for the host.
2. Issues an HTTP(S) request (URLs/domains) or a TCP 443 probe (IPs) to trigger Network Protection.
3. Waits a short delay for Defender to flush its events.
4. Reads `Microsoft-Windows-Windows Defender/Operational` for event IDs `1125` (NP audit) and `1126` (NP block).
5. Reads `Microsoft-Windows-SmartScreen/Debug` for any SmartScreen verdict.
6. Writes `<input>_Validated_<timestamp>.xlsx` with three sheets: `Summary`, `Already Covered by NP-SmartScreen`, `All Indicators`.

The `OverallVerdict` column tells you the action:

| Verdict | Meaning |
| --- | --- |
| `Covered-NP-Block` | Network Protection blocked the connection (event 1126). Safe to remove from MDE. |
| `Covered-NP-Audit` | Network Protection logged the connection in audit mode (event 1125). MDE block list still useful until NP is flipped to Block. |
| `Covered-SmartScreen` | SmartScreen flagged the URL. Safe to remove if browsers are the only access path. |
| `Not-Covered-Keep-In-MDE` | No NP or SmartScreen event fired. Keep the indicator in MDE. |
| `Error-NoResolution` | DNS failed, indicator could not be detonated. Recheck manually. |

## Why no cloud auth

Everything runs locally on the lab host. NP and SmartScreen write their verdicts to Windows event logs, so the script just triggers a lookup, then reads the logs. No API key, no app registration, no tenant access needed.

## Prerequisites

Run on a Windows 10 or 11 lab host (or Windows Server with Defender) where:

- You are an Administrator (event logs require elevation).
- Microsoft Defender Antivirus is active (not a third-party AV).
- Network Protection is enabled in Block or Audit mode:

  ```powershell
  Set-MpPreference -EnableNetworkProtection 1   # 1 = Block, 2 = Audit
  ```

- SmartScreen is on (default on Windows 10/11).
- `ImportExcel` module (auto installed on first run).

The script refuses to run if NP is disabled.

## How to run

1. Export your URL/Domain indicators from MDE: Settings, Endpoints, Indicators, URLs/Domains, Export.
2. Drop the exported `.csv` or `.xlsx` into this folder next to `Validate-UrlDomainIOCs.ps1`.
3. Open PowerShell as Administrator in this folder and run:

   ```powershell
   .\Validate-UrlDomainIOCs.ps1
   ```

   The script auto picks the newest non `Validated` CSV or XLSX in the folder.

4. When it finishes, `Url_Validated_<timestamp>.xlsx` opens automatically.

### Optional parameters

| Parameter | Purpose |
| --- | --- |
| `-InputPath` | Explicit path to the input file |
| `-OutputPath` | Explicit path for the output `.xlsx` |
| `-PerIndicatorDelayMs` | Milliseconds to wait after detonation before reading events (default 2500) |
| `-HttpTimeoutSec` | HTTP request timeout in seconds (default 5) |

Example:

```powershell
.\Validate-UrlDomainIOCs.ps1 -InputPath .\Url.csv -PerIndicatorDelayMs 4000
```

## Input format

The script accepts the native MDE indicator export schema:

```
Indicator Value, Indicator Type, Creation Time, Created By, Action, Severity, Title, Description, Category, Generate Alert
```

It looks for these column names (case insensitive):

- `Indicator Value` (or `IndicatorValue`, `Url`, `Domain`, `Indicator`)
- `Indicator Type` (optional, auto detected as `Url` / `DomainName` / `IpAddress`)

A sample is included as `Url.sample.csv`.

## Output columns

| Column | Source |
| --- | --- |
| `IndicatorValue`, `IndicatorType`, `TargetHost` | Input / parsed |
| `DnsResolved` | DNS lookup result |
| `HttpStatus` | HTTP response or `TcpOpen` / `TcpBlocked` for IPs |
| `NpStatus` | `Blocked`, `Audited`, or `NotTriggered` |
| `NpEventId`, `NpEventTime`, `NpThreatName`, `NpRaw` | From event 1125/1126 payload |
| `SmartScreenStatus` | `Flagged` or `NotTriggered` |
| `SmartScreenEventTime`, `SmartScreenSource` | SmartScreen event metadata |
| `OverallVerdict` | See table above |
| `DetonationError` | Any error from the detonation step (often the block itself) |

## Caveats

- A blocked HTTP request often surfaces as an exception in PowerShell. That is expected and is captured in `DetonationError`. The NP event log entry is the source of truth.
- SmartScreen-for-URLs primarily fires from a browser. If the indicator only triggers SmartScreen and not NP, run a few of the URLs through Edge to confirm in addition to this script.
- Audit-mode NP does not actually block traffic. If you see `Covered-NP-Audit` for everything, your fleet is not protected until NP is set to Block.
- Run this on a non-production VM. You are intentionally connecting to known-bad infrastructure.

## Screenshots
