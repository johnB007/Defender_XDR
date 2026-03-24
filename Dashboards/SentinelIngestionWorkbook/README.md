# Sentinel Ingestion Monitoring Workbook

## Intro
This package publishes a Microsoft Sentinel / Azure Monitor workbook for tracking log ingestion volume and cost across all billable data sources in a Log Analytics workspace.
It is built for day-1 operations with:
- Daily ingestion volume by data source in TB and GB
- Device table breakouts for MDE telemetry cost tracking
- Per-vendor event counts across all Device table categories
- Click-to-drilldown on any chart segment to surface raw log records
- Export support on all detail grids for cost review and vendor conversations

## Summary For Sysadmin And Security
This workbook gives cost teams and SOC analysts a shared view of what is driving ingestion spend and where spikes are coming from.
- Find which data sources are growing fastest and flag them for review before billing cycles close.
- Click any vendor or data type in a chart to pull the raw records behind the spike and export for investigation.

### Tab Breakdown
| Tab | Sysadmin And Security Use |
|---|---|
| Sentinel Ingestion-Total | Review total daily billable ingestion by data source. Click any segment to pull raw Usage records for that source. |
| Ingestion - Non Device Related | Isolate non-MDE sources driving cost. Useful for tracking SecurityEvent, BehaviorAnalytics, and cloud diagnostic log growth. |
| Device Tables (Breakout) | Compare MDE device table volume side by side in GB per day. Identify which table category is driving the largest share. |
| DeviceEvents | Track event counts by vendor for the DeviceEvents table. Click any vendor bar to pull matching records below. |
| Device File Events | Track file activity event counts by vendor. Click a vendor to review file paths, command lines, and SHA256 hashes. |
| Device Process Events | Track process execution counts by vendor. Click a vendor to review process names, command lines, and account context. |
| Device Network Events | Track network connection counts by vendor. Click a vendor to review remote IPs, ports, URLs, and protocol detail. |
| Device Registry Events | Track registry change counts by vendor. Click a vendor to review key paths, value names, and data before and after. |
| Device Image Load Events | Track DLL and image load counts by vendor. Click a vendor to review file signing status, issuer, and load context. |

## Workbook Overview Screenshots

### Sentinel Ingestion-Total Tab
<img width="1899" height="876" alt="image" src="https://github.com/user-attachments/assets/9450f102-34b3-4d6e-b37b-b6d14ac33a83" />
<img width="1883" height="848" alt="image" src="https://github.com/user-attachments/assets/4804758e-d410-427c-959c-74a6cbcfdcfc" />

### Ingestion - Non Device Related Tab
<img width="1887" height="817" alt="image" src="https://github.com/user-attachments/assets/3ecdf568-5200-4fed-b09b-281bf84b0e64" />
<img width="1857" height="841" alt="image" src="https://github.com/user-attachments/assets/20bfa072-594a-4af6-b444-69d991eb4682" />


### Device Tables Breakout Tab
<img width="1883" height="762" alt="image" src="https://github.com/user-attachments/assets/d0ad4172-9eb9-4439-bdf0-15e65f0e6a58" />
<img width="1876" height="839" alt="image" src="https://github.com/user-attachments/assets/9eda07f9-8732-42b3-91fd-7c9d23b71be6" />


### DeviceEvents Tab
<img width="1890" height="819" alt="image" src="https://github.com/user-attachments/assets/e8c13d75-7214-4cd7-9e54-d8d04e363e03" />
<img width="1878" height="804" alt="image" src="https://github.com/user-attachments/assets/13187a93-7f39-4111-9b53-5758c9b60a8a" />
<img width="1876" height="836" alt="image" src="https://github.com/user-attachments/assets/be453b42-6b77-460a-9a1e-b9f61e672e86" />


## Section Details And What Each One Does

### Sentinel Ingestion-Total
- What it does: queries the Usage table for all billable data sources and plots daily ingestion volume in TB per source.
- Primary visuals: stacked column chart by DataType, time-series trend, top contributor summary.
- Why it matters: gives cost teams a daily view of what is driving total Sentinel spend and flags sources growing outside normal patterns.

### Ingestion - Non Device Related
- What it does: filters the Usage table to non-Device sources and plots daily TB ingestion by source.
- Primary visuals: stacked column chart scoped to non-MDE tables, detail grid on click.
- Why it matters: separates SIEM, identity, and cloud diagnostic cost from MDE volume so each can be tracked and attributed separately.

### Device Tables Breakout
- What it does: pulls Usage records for all Device tables and shows daily GB ingestion per table as an unstacked bar chart.
- Primary visuals: side-by-side bar chart with DeviceFileEvents, DeviceNetworkEvents, DeviceProcessEvents, DeviceRegistryEvents, DeviceImageLoadEvents, DeviceLogonEvents, DeviceNetworkInfo.
- Why it matters: identifies which MDE device table category is the largest cost contributor and how volume shifts day to day.

### DeviceEvents
- What it does: counts DeviceEvents records by vendor per day, excluding Microsoft, Google, and blank vendors, and renders a column chart.
- Primary visuals: stacked column chart by InitiatingProcessVersionInfoCompanyName, detail grid on vendor click.
- Why it matters: surfaces third-party agents generating the most DeviceEvents volume for cost attribution and tuning.

### Device File Events
- What it does: counts DeviceFileEvents records by vendor per day with the same vendor filters applied.
- Primary visuals: stacked column chart by vendor, detail grid showing FileName, FolderPath, ActionType, CommandLine, SHA256, and account context on vendor click.
- Why it matters: identifies which security tools are generating the highest file activity telemetry and supports investigation of specific file operations by vendor.

### Device Process Events
- What it does: counts DeviceProcessEvents records by vendor per day.
- Primary visuals: stacked column chart by vendor, detail grid showing process name, command line, file version, and account on vendor click.
- Why it matters: shows which vendors are driving process execution event volume and supports triage of high-count vendors.

### Device Network Events
- What it does: counts DeviceNetworkEvents records by vendor per day.
- Primary visuals: stacked column chart by vendor, detail grid showing RemoteIP, RemotePort, RemoteUrl, Protocol, LocalIP, and process context on vendor click.
- Why it matters: identifies network-active vendor agents and supports investigation of unusual outbound connection patterns.

### Device Registry Events
- What it does: counts DeviceRegistryEvents records by vendor per day.
- Primary visuals: bar chart by vendor, detail grid showing RegistryKey, RegistryValueName, before and after values, and process context on vendor click.
- Why it matters: surfaces registry-active agents and helps triage mass registry write activity from specific vendors.

### Device Image Load Events
- What it does: counts DeviceImageLoadEvents records by vendor per day.
- Primary visuals: bar chart by vendor, detail grid showing FileName, FolderPath, IsSigned, Signer, Issuer, and process context on vendor click.
- Why it matters: identifies vendors generating high DLL and module load telemetry and supports review of unsigned or unexpected image loads.

## Prerequisites
- A Microsoft Sentinel-enabled Log Analytics workspace
- Read access to the Usage, DeviceFileEvents, DeviceNetworkEvents, DeviceProcessEvents, DeviceRegistryEvents, DeviceImageLoadEvents, and DeviceEvents tables
- Azure Monitor Workbooks contributor permissions to import and save the workbook

## The Structure
This folder contains:
- `SentinelIngestionWorkbook.json`: workbook JSON payload for manual import via Advanced Editor
- `azuredeploy.json`: one-click ARM deployment template

## How To Deploy
Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSentinelIngestionWorkbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSentinelIngestionWorkbook%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- `workspaceName`: your Log Analytics workspace name (default: `SOC-Central`)
- `workbookDisplayName`: display name shown in Sentinel (default: `Sentinel Ingestion Monitoring Workbook`)
- `workbookId`: leave the default generated value, or provide your own GUID to update an existing instance

### Deployment Note
Azure workbook resources require the underlying resource name to be a GUID. The friendly workbook title comes from `workbookDisplayName`.

## Manual Import (Portal)
1. Go to Microsoft Sentinel in your target workspace.
2. Select **Workbooks**, then **New**.
3. Open **Advanced Editor**.
4. Paste the contents of `SentinelIngestionWorkbook.json`.
5. Apply and Save.

## Notes
- The workbook queries the `Usage` table for ingestion data — ensure the workspace billing model includes this table.
- If data appears delayed after deployment, allow several minutes for table refresh and workbook rendering.
