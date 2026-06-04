# Bulk IOC Validation

PowerShell tools to review your Microsoft Defender for Endpoint (MDE) custom IOCs and find the ones you can remove.

Use these on older or OSINT IOCs that have been sitting in the tenant. Do not use them on IOCs tied to an active campaign, an open IR case, or anything your SOC is hunting on right now. Leave those alone.

## What's here

| Folder | What it does |
|---|---|
| [Hash](./Hash) | Checks file hash IOCs against VirusTotal so you can drop the ones MDAV already detects. |
| [URL Domain](./URL%20Domain) | Runs URL, Domain, and IP IOCs through a lab host with Network Protection and SmartScreen, then reads the local event logs to see what got blocked. |

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
