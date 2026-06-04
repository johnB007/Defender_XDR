# Bulk IOC Validation

PowerShell tools for validating Microsoft Defender for Endpoint (MDE) custom IOCs in bulk, so you can clean out stale indicators and keep only the ones that still need to live in MDE.

These tools are meant for cleaning up older, general-purpose, or OSINT-sourced IOCs that have been sitting in your tenant. They are **not** intended for IOCs tied to an active threat actor campaign, an incident-response engagement, or any indicator your SOC is currently using for hunting or attribution. Keep those in place.

## What's here

| Folder | What it does |
|---|---|
| [Hash](./Hash) | Checks file hash IOCs against VirusTotal so you can drop the ones already widely detected by AV. |
| [URL Domain](./URL%20Domain) | Detonates URL / Domain / IP IOCs on a lab host with Network Protection and SmartScreen enabled, then reads the local event logs to see what got blocked. |

Each subfolder has its own README with the full usage, the CSV format, and the exact columns produced in the output XLSX.

## Prerequisites (do this once before the first run)

1. **PowerShell 7** (recommended) or Windows PowerShell 5.1, run **as Administrator**.
2. **Install the ImportExcel module once.** Open an elevated PowerShell window and run:

   ```powershell
   Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber
   ```

   You may see a one-time "Untrusted repository" prompt — answer **Y**. When the prompt comes back to a blank line, the install is done.

   > On PowerShell 7 you can ignore any `Install-PackageProvider NuGet` warning you may have seen in older guides. PS7 does not use that provider and `Install-Module` works directly against PSGallery.

3. **Close that window and open a new PowerShell window** before running any script. PowerShell can't always pick up a freshly installed module in the same session.
4. Verify it's there:

   ```powershell
   Get-Module -ListAvailable ImportExcel
   ```

5. Page-specific extras:
   - **Hash**: a VirusTotal API key (free tier works).
   - **URL Domain**: a lab/test Windows host with Network Protection **and** SmartScreen enabled. Do not run on a production endpoint.

## Typical workflow

1. Export your custom indicators from the MDE portal (Settings -> Endpoints -> Indicators).
2. Drop the file in the matching subfolder (`Hash` or `URL Domain`).
3. Run the script for that page (see its README).
4. Open the generated XLSX, review the Summary sheet, and remove the "already covered" indicators from MDE.
