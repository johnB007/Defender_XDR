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

1. **Windows PowerShell 5.1 or PowerShell 7+**, run **as Administrator**.
2. **Install the ImportExcel module** in a fresh elevated window:

   ```powershell
   Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber
   ```

   If that fails with a NuGet / TLS / repository error, run this first and then retry:

   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force
   Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
   Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber
   ```

   Then **close and reopen PowerShell** before running any script.

3. Page-specific extras:
   - **Hash**: a VirusTotal API key (free tier works).
   - **URL Domain**: a lab/test Windows host with Network Protection **and** SmartScreen enabled. Do not run on a production endpoint.

## Typical workflow

1. Export your custom indicators from the MDE portal (Settings -> Endpoints -> Indicators).
2. Drop the file in the matching subfolder (`Hash` or `URL Domain`).
3. Run the script for that page (see its README).
4. Open the generated XLSX, review the Summary sheet, and remove the "already covered" indicators from MDE.
