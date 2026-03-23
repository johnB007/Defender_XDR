# Sentinel Ingestion Monitoring Workbook
### SysAdmin — MDE Deployment | Azure Monitor Workbook

> **Audiences:** SOC Analysts · Cost Management Teams · Security Operations Leadership  
> **Workspace:** `milz-operations-prod-log` (daf-sentinel-prod)  
> **Last Updated:** March 2026

---

## Overview

This Azure Monitor Workbook provides a centralized, interactive view of **Microsoft Sentinel log ingestion** across all billable data sources in the Log Analytics Workspace. It is designed to serve two primary audiences:

- **Cost Teams** — Track daily ingestion volumes (TB/GB) per data source to identify cost drivers, unexpected growth, and billing anomalies before they impact budget.
- **SOC / Security Operations** — Investigate vendor-specific ingestion spikes in real time, correlate volume increases with raw event data, and export findings for incident reports or vendor conversations.

---

## Screenshots

### 1. Sentinel Ingestion — Total View
> *Screenshot: Overall stacked column chart showing TBs per day by DataType across the selected time range.*

![Sentinel Ingestion Total](screenshots/01-sentinel-ingestion-total.png)

**What you're seeing:** Every billable data source in Sentinel plotted as a stacked bar per day. The legend shows the top contributors by volume. Larger bars on specific dates indicate ingestion spikes worth investigating.

---

### 2. Non-Device Ingestion Breakdown
> *Screenshot: Filtered view showing only non-Device tables (SecurityEvent, BehaviorAnalytics, StorageFileLogs, etc.)*

![Non Device Ingestion](screenshots/02-non-device-ingestion.png)

**What you're seeing:** The same TB-per-day view scoped to non-device tables — typically SIEM/identity/cloud log sources. Useful for spotting anomalies in sources like `SecurityEvent` (high-value, high-cost) or `AzureDiagnostics`.

---

### 3. Device Tables Breakout (GB per day)
> *Screenshot: Unstacked bar chart comparing DeviceFileEvents, DeviceNetworkEvents, DeviceProcessEvents, etc. side by side.*

![Device Tables Breakout](screenshots/03-device-tables-breakout.png)

**What you're seeing:** MDE device telemetry tables broken out individually in GB per day. This view shows which device table category (file, network, process, registry, image load) is driving the most volume, helping prioritize tuning efforts.

---

### 4. Drill-Down Detail Grid (Click-to-Investigate)
> *Screenshot: After clicking Tenable's color segment — detail grid appears below showing raw DeviceFileEvents rows.*

![Drilldown Detail Grid](screenshots/04-drilldown-detail-grid.png)

**What you're seeing:** When you click any colored segment or vendor bar in a chart, a detail grid appears below the chart automatically. The grid shows the raw log records filtered to that vendor/data type with full field visibility and an Export (↓) button for CSV download.

---

## How to Use This Workbook

### Investigating a Spike (e.g., Tenable)

1. Open the workbook in Azure Monitor and select your time range (default: last 7 days).
2. Navigate to the **Device File Events** tab (or whichever tab shows the spike).
3. **Click the Tenable color bar** in the chart — the detail grid populates below automatically.
4. Review the columns: `DeviceName`, `FileName`, `FolderPath`, `InitiatingProcessCommandLine`, `SHA256`, `AccountName`.
5. Use the column **filter bar** to narrow down by device, file path, or time.
6. Click the **Export (↓)** button on the grid to download the full result set as CSV.
7. Share the CSV with the cost team or vendor for investigation.

### Time Range
Use the **Time Picker** pill at the top to adjust the analysis window:

| Option | Use Case |
|---|---|
| 7 days | Spot short-term spikes, current week review |
| 14 days | Compare this week vs last week |
| 30 days | Monthly cost reporting |
| 60 / 90 days | Trend analysis, capacity planning |
| Custom | Targeted incident time windows |

---

## Tabs Reference

| Tab | Data Source | Unit | Best For |
|---|---|---|---|
| Sentinel Ingestion-Total | `Usage` (all billable) | TB/day | Full cost picture |
| Ingestion - Non Device Related | `Usage` (!Device tables) | TB/day | SIEM/identity cost drivers |
| Device Tables (Breakout) | `Usage` (Device* tables) | GB/day | MDE table-level volume |
| DeviceEvents | `DeviceEvents` | Event count | Vendor event volume |
| Device File Events | `DeviceFileEvents` | Event count | File activity by vendor |
| Device Process Events | `DeviceProcessEvents` | Event count | Process execution by vendor |
| Device Network Events | `DeviceNetworkEvents` | Event count | Network connections by vendor |
| Device Registry Events | `DeviceRegistryEvents` | Event count | Registry changes by vendor |
| Device Image Load Events | `DeviceImageLoadEvents` | Event count | DLL/image loads by vendor |

---

## Importing the Workbook

1. Go to **Azure Portal → Azure Monitor → Workbooks → + New**
2. Click the **`</>`** (Advanced Editor) toolbar button
3. Paste the full contents of `SentinelIngestionWorkbook.json`
4. Click **Apply**, then **Save** to your resource group

---

## Files in This Folder

```
SysAdmin-MDE-Deployment-Workbook/
├── README.md                        ← This file
├── SentinelIngestionWorkbook.json   ← Import into Azure Monitor Workbooks
└── screenshots/                     ← Add screenshots here after first deployment
    ├── 01-sentinel-ingestion-total.png
    ├── 02-non-device-ingestion.png
    ├── 03-device-tables-breakout.png
    └── 04-drilldown-detail-grid.png
```

---

## Notes for Cost Team

- All ingestion queries source from the **`Usage`** table which reflects **billable MB** (converted to GB/TB in the workbook).
- The `Quantity` field in `Usage` is in **MB** — the workbook divides by 1,024 for GB and 1,048,576 for TB.
- `SecurityEvent` is typically the #1 non-device cost driver. `DeviceFileEvents` and `DeviceNetworkEvents` dominate device-side cost.
- Tenable, OPSWAT, ForeScout, and similar EDR/vulnerability tools tend to generate high `DeviceFileEvents` and `DeviceImageLoadEvents` volume.
- Use the Export feature on the drill-down grids to pull raw records and share with vendors asking for justification on data reduction requests.

## Notes for SOC Team

- The **Device Events tabs exclude Microsoft, Google, and blank-vendor events** by design — these are filtered to focus on third-party agents generating anomalous volume.
- Drill-down grids include `InitiatingProcessCommandLine` and `SHA256` hashes for triage.
- Network event drill-downs surface `RemoteIP`, `RemotePort`, `RemoteUrl`, and `Protocol` for threat hunting on suspicious outbound patterns.
- Image Load events include `IsSigned`, `Signer`, and `Issuer` columns — useful for identifying unsigned or suspicious DLL loads from a specific vendor process.

It is designed for quick deployment and easy day-1 use with:
- Compliance posture views
- EDR and AV sensor health views
- Threat event summaries
- DLP USB activity views
- Intune firewall policy evidence views

## Summary For SOC And CISO
This workbook gives SOC teams fast operational triage while also giving CISO leaders clear risk posture trends.

- SOC focus: Find unhealthy endpoints, identify detection spikes, and prioritize remediation.
- CISO focus: Track coverage, compliance, and operational effectiveness over time.

### Tab Breakdown
| Tab | SOC Use | CISO Use |
|---|---|---|
| Compliance | Find non-compliant systems by last check-in and prioritize follow-up. | Measure enterprise endpoint compliance rate and trend. |
| EDR Sensor | Detect inactive or unhealthy EDR sensors before blind spots grow. | Confirm sensor health baseline across the environment. |
| AV Sensor | Validate AV telemetry presence and identify stale/non-reporting devices. | Verify anti-malware coverage effectiveness at a glance. |
| EDR/AV Install Status | Separate devices into EDR+AV, AV only, EDR only, and no coverage groups. | Understand tooling coverage gaps and exposure concentration. |
| Firewall Events | Triage blocked/allowed patterns and investigate suspicious network behavior. | Review firewall activity posture and abnormal activity growth. |
| Threat Events | Investigate incidents, severities, and source concentration quickly. | Track top threats, incident volume, and high-severity burden. |
| DLP Events | Review USB/removable media events and potential exfiltration signals. | Monitor data protection control effectiveness and policy pressure. |
| Intune Compliance | Correlate FW policy assignment with sync/compliance evidence. | Validate policy rollout quality and follow-up performance. |


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
