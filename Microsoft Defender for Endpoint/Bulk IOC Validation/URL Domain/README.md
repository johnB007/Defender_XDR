# URL / Domain IOC Validation

PowerShell script that validates URL, Domain, and IP IOCs from a Microsoft Defender for Endpoint (MDE) export by running each one through a lab host with Microsoft Defender Antivirus (MDAV), Network Protection (NP), and SmartScreen on. It reads the local Defender event logs and reports what got blocked so you know which indicators to remove from MDE.

## What it does

For every Url, DomainName, or IpAddress row in your MDE export the script:

1. Resolves DNS for the host.
2. Issues an HTTP(S) request (URL or domain) or a TCP 443 probe (IP) to trigger Network Protection.
3. Waits for Defender to flush its events.
4. Reads `Microsoft-Windows-Windows Defender/Operational` for event IDs `1125` (NP audit) and `1126` (NP block).
5. Reads `Microsoft-Windows-SmartScreen/Debug` for any SmartScreen verdict.
6. Writes `<input>_Validated_<timestamp>.xlsx` with three sheets: `Summary`, `Already Covered by NP-SmartScreen`, `All Indicators`.

The `OverallVerdict` column tells you what to do:

| Verdict | Meaning |
|---|---|
| `Covered-NP-Block` | NP blocked the connection (event 1126). Remove from MDE. |
| `Covered-NP-Audit` | NP logged the connection in audit mode (event 1125). Keep the MDE block until NP is set to Block. |
| `Covered-SmartScreen` | SmartScreen flagged the URL. Remove from MDE if browsers are the only access path. |
| `Not-Covered-Keep-In-MDE` | No NP or SmartScreen event fired. Keep the indicator in MDE. |
| `Error-NoResolution` | DNS failed. Recheck manually. |

## Why no cloud auth

Everything runs locally on the lab host. NP and SmartScreen write verdicts to Windows event logs. The script triggers the lookup, then reads the logs. No API key, no app registration, no tenant access.

## Prerequisites

Run on a Windows 10 or 11 lab host (or Windows Server with Defender) where:

- You are an Administrator (event logs need elevation).
- Microsoft Defender Antivirus is active (not a third party AV).
- Network Protection is on in Block or Audit mode:

  ```powershell
  Set-MpPreference -EnableNetworkProtection 1   # 1 = Block, 2 = Audit
  ```

- SmartScreen is on (default on Windows 10/11).
- `ImportExcel` module. Install it once before the first run, see the parent [Bulk IOC Validation README](../README.md#install-importexcel-once-before-you-run-anything).

The script refuses to run if NP is disabled.

## How to run

1. Export your URL/Domain indicators from MDE: Settings, Endpoints, Indicators, URLs/Domains, Export.
2. Drop the `.csv` or `.xlsx` into this folder next to `Validate-UrlDomainIOCs.ps1`.
3. Run PowerShell as Administrator in this folder:

   ```powershell
   .\Validate-UrlDomainIOCs.ps1
   ```

   The script picks the newest non `Validated` CSV or XLSX in the folder.

4. When it finishes, `Url_Validated_<timestamp>.xlsx` opens.

### Optional parameters

| Parameter | Purpose |
|---|---|
| `-InputPath` | Path to the input file |
| `-OutputPath` | Path for the output `.xlsx` |
| `-PerIndicatorDelayMs` | Milliseconds to wait after detonation before reading events (default 2500) |
| `-HttpTimeoutSec` | HTTP request timeout in seconds (default 5) |

Example:

```powershell
.\Validate-UrlDomainIOCs.ps1 -InputPath .\Url.csv -PerIndicatorDelayMs 4000
```

## Input format

Native MDE indicator export schema:

```
Indicator Value, Indicator Type, Creation Time, Created By, Action, Severity, Title, Description, Category, Generate Alert
```

Recognized column names (case insensitive):

- `Indicator Value` (or `IndicatorValue`, `Url`, `Domain`, `Indicator`)
- `Indicator Type` (optional, auto detected as `Url`, `DomainName`, or `IpAddress`)

`Url.sample.csv` is included.

## Output columns

| Column | Source |
|---|---|
| `IndicatorValue`, `IndicatorType`, `TargetHost` | Input or parsed |
| `DnsResolved` | DNS lookup result |
| `HttpStatus` | HTTP response, or `TcpOpen` / `TcpBlocked` for IPs |
| `NpStatus` | `Blocked`, `Audited`, or `NotTriggered` |
| `NpEventId`, `NpEventTime`, `NpThreatName`, `NpRaw` | Event 1125/1126 payload |
| `SmartScreenStatus` | `Flagged` or `NotTriggered` |
| `SmartScreenEventTime`, `SmartScreenSource` | SmartScreen event metadata |
| `OverallVerdict` | See table above |
| `DetonationError` | Any error from the detonation step (often the block itself) |

## Notes

- A blocked HTTP request usually shows up as a PowerShell exception. That is expected and is captured in `DetonationError`. The NP event log is the source of truth.
- SmartScreen for URLs fires from a browser. If an indicator only triggers SmartScreen, run a few of them through Edge to confirm.
- Audit-mode NP does not block traffic. If you see `Covered-NP-Audit` for everything, your fleet is not protected until NP is set to Block.
- Run on a non-production VM. You are intentionally connecting to known-bad infrastructure.

## Screenshots
