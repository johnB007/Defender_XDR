# DC SYSVOL and AD Replication Health Monitor

## Intro
This package publishes a Microsoft Sentinel / Azure Monitor workbook for Domain Controller replication health from a sysadmin and security operations perspective. Using the XPath: `DFS Replication!*`, `Directory Service!*`. NTFRS / File Replication Service is **deprecated by Microsoft starting Windows Server 2008 R2** and **removed in Windows Server 2012+**, so this workbook now tracks only DFSR and Directory Service.

It is built for day-1 operations with:
- Environment-wide replication KPIs
- DFSR deep-dive troubleshooting views
- Directory Service replication and DNS dependency analysis
- Cross-source critical event triage
- Per-DC health scoring and silent host detection
- DC Locations world map (Heartbeat geo + MDE DeviceInfo)
- Log volume and cost estimation

## Summary For Sysadmin And Security
This workbook gives sysadmin and security teams fast triage coverage for replication-impacting issues, clear visibility into risk concentration, and practical operational trends for remediation.

- Find failing DCs quickly, prioritize highest-impact replication faults, and track recovery.
- Understand replication risk posture, affected scope, and sustained stability trends.

### Tab Breakdown
| Tab | Sysadmin And Security Use |
|---|---|
| Overview | Validate whether replication telemetry is healthy and complete across all DCs, and review high-level health and severity posture in one view. |
| DFS Replication | Investigate DFSR stoppage, out-of-sync conditions, and service disruption patterns while tracking concentration of critical DFSR conditions over time. |
| DC Locations | Plot every Domain Controller on a world map using Heartbeat geolocation and MDE `DeviceInfo` enrichment. Confirm physical placement, regional spread, and surface DCs reporting from unexpected locations. |
| Directory Service | Investigate AD replication failures, KCC topology issues, and DNS-linked faults while monitoring enterprise directory health risk. |
| Security and MDE | Correlate focus event IDs with SecurityEvent, MDE, and Arc operational signals to measure telemetry breadth for DC assets. |
| Critical Events | Prioritize multi-source failures and highest-severity events for immediate action while tracking systemic risk across replication subsystems. |
| DC Health Matrix | Score each DC by subsystem health and identify silent or degraded systems quickly while reviewing enterprise-wide health distribution and outliers. |
| Log Volume and Cost | Estimate billed volume trends and projected 30-day cost by source and host to forecast cost exposure and optimize telemetry investment. |

## Workbook Overview Screenshots

### Overview Tab
<img width="1834" height="456" alt="image" src="https://github.com/user-attachments/assets/13484e32-76cd-48c3-b72b-007353873349" />
<img width="1873" height="728" alt="image" src="https://github.com/user-attachments/assets/225a53c6-b6e1-4a68-a584-7e7f55d86887" />
<img width="1862" height="561" alt="image" src="https://github.com/user-attachments/assets/782a1877-1bd7-4261-8e93-412156bca0a6" />


### DFS Replication Tab
<img width="1859" height="717" alt="image" src="https://github.com/user-attachments/assets/59d95958-d088-4819-8c99-7192b96e9147" />


### DC Locations Tab
_World map of all Domain Controllers with Heartbeat geo telemetry. Add screenshot after first publish._


### Directory Service Tab
<img width="1861" height="696" alt="image" src="https://github.com/user-attachments/assets/ffde1782-9da2-435e-a2d3-02c388a15da5" />


### Security and MDE Tab
<img width="1868" height="723" alt="image" src="https://github.com/user-attachments/assets/8efe638d-8083-420f-be0b-c4f568258ac3" />


### Critical Events Tab


### DC Health Matrix Tab
<img width="1872" height="743" alt="image" src="https://github.com/user-attachments/assets/511c9f79-1005-40f3-984b-487138c888ff" />


### Log Volume and Cost Tab
<img width="1844" height="696" alt="image" src="https://github.com/user-attachments/assets/5be912f5-43a9-459b-ba30-404631a825e1" />


## Section Details And What Each One Does

### Overview
- What it does: provides enterprise-level KPI and trend snapshots across DFS Replication, File Replication Service, and Directory Service logs.
- Primary visuals: KPI tiles, event volume timeline, source distribution, severity mix, top DC summary.
- Why it matters: confirms collection coverage and quickly identifies whether replication risk is rising or isolated.

### DFS Replication
- What it does: focuses on DFSR-specific replication failures and service health indicators.
- Primary visuals: critical event ID trends, top impacted DCs, service stop/start/halt timelines, detailed recent error table.
- Why it matters: catches 2213/4012/5002/6016 class failures that can interrupt SYSVOL consistency.

### DC Locations
- What it does: plots every reporting Domain Controller on a world map and joins Heartbeat geo with MDE `DeviceInfo`.
- Primary visuals: world map (sized by heartbeat volume, colored by reporting freshness), country bar chart, status pie, and a full enrichment table with `Latitude`, `Longitude`, `Country`, `OSName`, `PublicIP`, and `OnboardingStatus`.
- Why it matters: confirms expected DC placement, exposes drift from documented sites, and helps spot DCs reporting from unexpected egress IPs.

### Directory Service
- What it does: analyzes AD replication and topology health from Directory Service events.
- Primary visuals: AD replication event distributions, DNS failure breakdown (2087/2088), replication failure detail by DC.
- Why it matters: surfaces isolated DCs, KCC path failures, and directory-level replication integrity risk.

### Security and MDE
- What it does: combines high-priority replication event IDs with SecurityEvent, MDE operational signals, and Arc heartbeat visibility.
- Primary visuals: focus event KPI set, source trend comparisons, DC signal summary for network/process/logon activity.
- Why it matters: gives sysadmin and security teams a cross-domain operational view for correlation and faster triage decisions.

### Critical Events
- What it does: unifies critical and error-level events across all three replication data sources.
- Primary visuals: cross-source timeline, source-stacked error distribution, multi-source impact table, full detail feed.
- Why it matters: prioritizes systems failing in multiple subsystems where business impact is highest.

### DC Health Matrix
- What it does: produces a per-DC scorecard across DFSR and Directory Service with an overall health state.
- Primary visuals: scorecard table, stacked error totals, hourly error-rate summary, silent DC detection.
- Why it matters: supports daily operational review and helps teams rank remediation by measurable risk.

### Log Volume and Cost
- What it does: estimates ingestion and cost from billed-size telemetry for workbook-covered events.
- Primary visuals: KPI tiles, daily billed trend, by-source volume/cost, per-device 30-day projection.
- Why it matters: ties operational telemetry value to spend so teams can optimize signal quality and budget.

## Prerequisites
- A Microsoft Sentinel-enabled Log Analytics workspace
- Permissions to deploy ARM templates in the target resource group
- Reader access to relevant security and operations tables
- Event collection configured for:
  - DFS Replication
  - Directory Service
- `Heartbeat` table populated for the DC computers (provides `RemoteIPLatitude` / `RemoteIPLongitude` / `RemoteIPCountry` for the DC Locations tab)
- Optional but recommended: MDE `DeviceInfo` advanced hunting data for DC enrichment

## The Structure
This folder contains:
- SYSVOL-DC-Replication-Monitor.workbook: workbook JSON payload for manual import
- azuredeploy.json: one-click ARM deployment template
- README.md: documentation page for this workbook

## How To Deploy
Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSYSVOL-DC-Replication-Monitor%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSYSVOL-DC-Replication-Monitor%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- workbookDisplayName: DC SYSVOL and AD Replication Health Monitor (or your preferred name)
- workbookSourceId: full resource ID of your target Log Analytics workspace
- workbookType: sentinel (default) or workbook
- workbookId: keep generated GUID unless updating an existing workbook resource

## Manual Import (Portal)
1. Go to Microsoft Sentinel in your target workspace.
2. Select Workbooks, then New.
3. Open Advanced Editor.
4. Paste the contents of SYSVOL-DC-Replication-Monitor.workbook.
5. Apply and Save.

## How To Publish This Page To GitHub
1. Save changes in this folder.
2. Commit and push to your repository.
3. Open this folder in GitHub to verify README rendering.
