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

### Use an MDE-offboarded lab host

Every detonation that matches a custom IOC fires the real MDE alert in the portal. On a 5,000 indicator run that is 5,000 alerts in your queue. Run this script on a Windows 10 or 11 VM that is **not** onboarded to MDE.

- NP, SmartScreen, and Defender AV still work on an offboarded host. They are built into the OS, not into MDE.
- Local event logs still record `1125` / `1126` for NP and the SmartScreen channel, which is all the script reads.
- Zero alerts fire in the portal because the host does not report there.

To offboard for testing: in the MDE portal go to `Settings -> Endpoints -> Offboarding -> Windows -> Local Script`, run the package, reboot. Re-onboard when you are done. The lab VM can stay on the corporate network or open internet, it just needs DNS and outbound 80/443 to detonate.

If offboarding is not an option, two fallbacks:

1. Bulk-edit the indicators to `Action = Audit` (or `Generate Alert = false`) for the run window, then revert. Detection still happens, no alert is raised. Risk: easy to forget to revert.
2. Create an MDE alert suppression rule scoped to the lab host name for the duration of the run, then delete it. Alert still fires and is stored, just hidden from the queue and from SIEM forwarding rules that filter on suppression.

#### Example: alert suppression rule for the lab host

In the MDE portal: **Settings -> Microsoft Defender XDR -> Rules -> Alert suppression -> Add**.

| Field | Value |
|---|---|
| **Rule name** | `LAB - IOC Validation run - <YYYY-MM-DD>` |
| **Triggering IOC** | leave empty |
| **Conditions** | `Device name` `equals` `LAB-IOC-VM01` (use your lab hostname) |
| **Action** | Hide alert |
| **Comment** | Bulk validation of URL/Domain custom IOCs. Delete this rule after the run completes. |
| **Scope** | All alerts that match the conditions |

Save and enable. After the script finishes, go back to the same page and **delete the rule** so future alerts on that host are not silently dropped.

Two important notes:

- Suppression is **per device**, not per indicator. Any other alert on that lab host during the window is also hidden. Do not do real work on the lab box while the rule is active.
- Alerts are still **created and stored** in the tenant, just marked resolved/hidden. They still count against retention. If your goal is zero storage impact, use the offboarded host approach instead.

If you prefer Advanced Hunting, you can confirm the rule is working with:

```kql
AlertInfo
| where Timestamp > ago(1h)
| where DeviceName == "LAB-IOC-VM01"
| summarize count(), HiddenCount = countif(DetectionSource has "WindowsDefenderAv" or Severity != "")
```

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

## Runtime and tuning for large lists

The script is serial by design. For each indicator it does DNS + HTTP (or TCP), waits for Defender to flush its events, then queries the local event log. On a healthy lab host expect roughly:

| Indicators | Default settings (`-PerIndicatorDelayMs 2500`) | Faster (`-PerIndicatorDelayMs 1000 -HttpTimeoutSec 3`) |
|---|---|---|
| 100 | ~6 minutes | ~3 minutes |
| 1,000 | ~1 hour | ~30 minutes |
| 5,000 | ~4 to 5 hours | ~2 hours |
| 10,000 | ~10 hours | ~4 hours |

Recommendations for enterprise lists:

- **Always run a 100 row sample first.** Confirm the verdicts look right before you commit the full list. If a tighter `-PerIndicatorDelayMs` starts producing false `Not-Covered-Keep-In-MDE` results for indicators you know NP blocks, raise the delay back.
- **Chunk the input.** Split a 5k file into five 1k files and run them in separate PowerShell windows on separate lab VMs. Output names are timestamped so they will not collide. Merge the XLSX afterwards.
- **Run overnight on a dedicated VM.** Lock the screen, plug in power, disable sleep. A 5k run will finish before morning.
- **Skip indicators you already know about.** If MDE shows hit counts on the indicators, prioritize the ones with zero hits over a long window; the recent-hit indicators are the ones you do not want to risk removing yet anyway.
- **Do not parallelize with the current script.** Concurrent detonations from one host will overlap in the event log and produce mismatched verdicts. Use separate hosts instead.

If your environment needs sub-hour runs on 5k+ indicators, the script can be refactored to do a single batch event-log scan after all detonations finish, which roughly halves the runtime. Open an issue if you want that variant.

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
- Audit mode NP does not block traffic. If you see `Covered-NP-Audit` for everything, your fleet is not protected until NP is set to Block.
- Run on a non production VM. You are intentionally connecting to known bad infrastructure.

## Screenshots
