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
![Sentinel Ingestion Total Tab - Placeholder 1](https://placehold.co/1600x900?text=Sentinel+Ingestion+Total+Screenshot+1)
![Sentinel Ingestion Total Tab - Placeholder 2](https://placehold.co/1600x900?text=Sentinel+Ingestion+Total+Screenshot+2)

### Ingestion - Non Device Related Tab
![Non Device Ingestion Tab - Placeholder 1](https://placehold.co/1600x900?text=Non+Device+Ingestion+Screenshot+1)
![Non Device Ingestion Tab - Placeholder 2](https://placehold.co/1600x900?text=Non+Device+Ingestion+Screenshot+2)

### Device Tables Breakout Tab
![Device Tables Breakout Tab - Placeholder 1](https://placehold.co/1600x900?text=Device+Tables+Breakout+Screenshot+1)
![Device Tables Breakout Tab - Placeholder 2](https://placehold.co/1600x900?text=Device+Tables+Breakout+Screenshot+2)

### DeviceEvents Tab
![DeviceEvents Tab - Placeholder 1](https://placehold.co/1600x900?text=DeviceEvents+Screenshot+1)
![DeviceEvents Tab - Placeholder 2](https://placehold.co/1600x900?text=DeviceEvents+Screenshot+2)

### Device File Events Tab
![Device File Events Tab - Placeholder 1](https://placehold.co/1600x900?text=Device+File+Events+Screenshot+1)
![Device File Events Tab - Placeholder 2](https://placehold.co/1600x900?text=Device+File+Events+Screenshot+2)

### Device Process Events Tab
![Device Process Events Tab - Placeholder 1](https://placehold.co/1600x900?text=Device+Process+Events+Screenshot+1)
![Device Process Events Tab - Placeholder 2](https://placehold.co/1600x900?text=Device+Process+Events+Screenshot+2)

### Device Network Events Tab
![Device Network Events Tab - Placeholder 1](https://placehold.co/1600x900?text=Device+Network+Events+Screenshot+1)
![Device Network Events Tab - Placeholder 2](https://placehold.co/1600x900?text=Device+Network+Events+Screenshot+2)

### Device Registry Events Tab
![Device Registry Events Tab - Placeholder 1](https://placehold.co/1600x900?text=Device+Registry+Events+Screenshot+1)
![Device Registry Events Tab - Placeholder 2](https://placehold.co/1600x900?text=Device+Registry+Events+Screenshot+2)

### Device Image Load Events Tab
![Device Image Load Events Tab - Placeholder 1](https://placehold.co/1600x900?text=Device+Image+Load+Events+Screenshot+1)
![Device Image Load Events Tab - Placeholder 2](https://placehold.co/1600x900?text=Device+Image+Load+Events+Screenshot+2)

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
- SentinelIngestionWorkbook.json: workbook JSON payload for manual import via Advanced Editor
- azuredeploy.json: one-click ARM deployment template


### Workbook Overview

### Compliance Tab
<img width="1876" height="718" alt="image" src="https://github.com/user-attachments/assets/9308526f-f707-4844-a718-9a242acaa448" />
<img width="1857" height="663" alt="image" src="https://github.com/user-attachments/assets/f0086a66-2c6e-480d-9085-c526278dd465" />

### EDR Sensor Tab
<img width="1672" height="682" alt="image" src="https://github.com/user-attachments/assets/58175256-31df-4e9b-9596-af262a05318f" />
<img width="1862" height="646" alt="image" src="https://github.com/user-attachments/assets/4ee6acad-930a-48e2-9e60-152c6f80f903" />

### AV Sensor Tab
<img width="1803" height="721" alt="image" src="https://github.com/user-attachments/assets/04a281af-df17-4eb9-8836-fda4f86d6caf" />
<img width="1874" height="681" alt="image" src="https://github.com/user-attachments/assets/33a06b2f-2ee6-4b42-b5b2-04105365c788" />

### EDR/AV Install Status Tab
<img width="1886" height="848" alt="image" src="https://github.com/user-attachments/assets/a3fc564d-534b-46f3-9e79-f7e36103e0bd" />
<img width="1877" height="818" alt="image" src="https://github.com/user-attachments/assets/d744359a-25a3-4c3c-bce1-878926d6ba86" />

### Firewall Events Tab
<img width="1875" height="854" alt="image" src="https://github.com/user-attachments/assets/bcdd23eb-c718-412e-9478-c963663b59f5" />
<img width="1875" height="646" alt="image" src="https://github.com/user-attachments/assets/aa5f4db5-2967-42b7-acbe-764c92133ecd" />

### Threat Events Tab
<img width="1711" height="805" alt="image" src="https://github.com/user-attachments/assets/b85eb262-bbc7-411c-85a8-67d156008d4d" />
<img width="1848" height="823" alt="image" src="https://github.com/user-attachments/assets/96d65aae-5350-49ee-835e-5798a546ab94" />

### DLP Events Tab
<img width="1868" height="837" alt="image" src="https://github.com/user-attachments/assets/f657772e-e715-4c85-ae27-07b2ccc442d4" />

### Intune Compliance Tab
<img width="1825" height="748" alt="image" src="https://github.com/user-attachments/assets/c11c3696-3246-4b4a-8daf-83ae1347bdce" />
<img width="1875" height="415" alt="image" src="https://github.com/user-attachments/assets/23a0c756-3b0c-4b40-9981-dac7c9d19a67" />



## Prerequisites
- A Microsoft Sentinel-enabled Log Analytics workspace
- Permissions to deploy ARM templates in the target resource group
- Reader access to relevant Microsoft Defender XDR data tables

## The Structure
This folder contains:
- SysAdmin-MDE-Deployment-Workbook.workbook: Workbook JSON payload for manual import
- azuredeploy.json: One-click ARM deployment template (Commercial + Gov)

## How To Deploy
Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSysAdmin-MDE-Deployment-Workbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSysAdmin-MDE-Deployment-Workbook%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- workspaceName: SOC-Central (or your target workspace name). If the portal kept text from a previous failed deployment, clear it and enter only the workspace name.
- workbookDisplayName: SysAdmin MDE Deployment Workbook (or your preferred title)
- workbookId: leave the default generated value, or provide your own GUID if you are updating an existing workbook instance

### Deployment Note
Azure workbook resources require the underlying resource name to be a GUID. The friendly workbook title still comes from `workbookDisplayName`.

## Manual Import (Portal)
1. Go to Microsoft Sentinel in your target workspace.
2. Select Workbooks, then New.
3. Open Advanced Editor.
4. Paste the contents of SysAdmin-MDE-Deployment-Workbook.workbook.
5. Apply and Save.

## How To Use
1. Select the time range at the top.
2. Use tabs to switch domains:
- Compliance
- EDR Sensor
- AV Sensor
- EDR/AV Install Status
- Firewall Events
- Threat Events
- DLP Events
- Intune Compliance
3. Use table filters and export options for triage and reporting.

## Notes
- The workbook uses fixed compliance windows in selected visuals and a global time picker for trend/detail views.
- If data appears delayed after deployment, allow several minutes for table refresh and workbook rendering.
