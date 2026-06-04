# Bulk IOC Validation

PowerShell tools to review your Microsoft Defender for Endpoint (MDE) custom IOCs and find the ones you can remove.

Use these on older or OSINT IOCs that have been sitting in the tenant. Do not use them on IOCs tied to an active campaign, an open IR case, or anything your SOC is hunting on right now. Leave those alone.

## What's here

| Folder | What it does |
|---|---|
| [Hash](./Hash) | Checks file hash IOCs against VirusTotal so you can drop the ones MDAV already detects. The Microsoft engine entry in VT (`last_analysis_results.Microsoft`) is what MDAV would call on a real endpoint, so a `MDAV-Malicious` or `MDAV-Suspicious` verdict means the hash is already covered. |
| [URL Domain](./URL%20Domain) | Runs URL and Domain IOCs through a lab host with Network Protection and SmartScreen, then reads the local event logs to see what got blocked. IP indicators are out of scope - leave them in MDE. |

Each subfolder has its own README with the exact usage, CSV format, and output columns.

## Install ImportExcel once before you run anything

1. Use PowerShell 7 or Windows PowerShell 5.1, as Administrator.
2. In an elevated window run:

   ```powershell
   Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber
   ```

   Answer Y if it asks about the untrusted PSGallery repository. When the prompt returns, it is done.

   On PowerShell 7 you can ignore any `Install-PackageProvider NuGet` error from older docs. PS7 does not use that provider.

3. Close that window. Open a new PowerShell window before you run the script.
4. Verify:

   ```powershell
   Get-Module -ListAvailable ImportExcel
   ```

5. Other requirements:
   - Hash: a VirusTotal API key (free tier is fine).
   - URL Domain: a lab Windows host with Network Protection and SmartScreen on. Do not run on a production endpoint.

## Workflow

1. Export your custom indicators from the MDE portal (Settings, Endpoints, Indicators).
2. Drop the file in the matching subfolder.
3. Run the script for that page.
4. Open the XLSX, review the Summary sheet, remove the indicators that are already covered from MDE.

## Why we do not test IP indicators

IP IOCs are intentionally out of scope for the URL/Domain validator. The two engines this repo relies on cannot give a useful verdict on a raw IP from a non-onboarded lab host:

- **SmartScreen only evaluates URLs and files.** It does not evaluate raw IP addresses, so every IP row would show `SmartScreenStatus: NotTriggered` regardless of the indicator's reputation. ([Microsoft Edge SmartScreen privacy docs](https://learn.microsoft.com/legal/microsoft-edge/privacy#smartscreen), [SmartScreen block criteria](https://learn.microsoft.com/troubleshoot/microsoft-edge/development/unexpected-block-warning#cause))
- **Network Protection can block by IP, but the default feed coverage for raw IPs is sparse and hostname keyed.** NP supports custom IP indicators (single external IPs, TCP/HTTP/HTTPS), but its built-in cloud feed (the part a non-onboarded box can exercise) is derived from the SmartScreen Intel feed, which is keyed on URLs and domains. Most malicious IPs do not show up there. ([Create indicators for IPs and URLs/domains Prerequisites](https://learn.microsoft.com/defender-endpoint/indicator-ip-domain#prerequisites), [Network protection overview](https://learn.microsoft.com/defender-endpoint/network-protection#why-network-protection-is-important))
- **Custom IP indicators take up to 48 hours to propagate** ([docs](https://learn.microsoft.com/defender-endpoint/indicator-ip-domain#policy-precedence)), which a one-shot lab probe cannot account for.

The practical outcome: an IP row scanned on a non-onboarded lab box would almost always come back `Not-Covered`, which is the right answer but tells you nothing new. **Keep IP indicators in MDE.** That is exactly the gap your custom IP IOC fills. The script tags any IP row it encounters as `IP-Not-Evaluated-Keep-In-MDE` and moves on.
