# DC SYSVOL and AD Replication Health Monitor

## Intro
This package publishes a Microsoft Sentinel / Azure Monitor workbook for Domain Controller replication health from a sysadmin and security operations perspective.

It is built for day-1 operations with:
- Environment-wide replication KPIs
- DFSR and NTFRS deep-dive troubleshooting views
- Directory Service replication and DNS dependency analysis
- Cross-source critical event triage
- Per-DC health scoring and silent host detection
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
| File Replication (NTFRS) | Triage journal wrap, SYSVOL not-ready state, and partner connectivity faults while assessing residual NTFRS risk in legacy or mixed environments. |
| Directory Service | Investigate AD replication failures, KCC topology issues, and DNS-linked faults while monitoring enterprise directory health risk. |
| Security and MDE | Correlate focus event IDs with SecurityEvent, MDE, and Arc operational signals to measure telemetry breadth for DC assets. |
| Critical Events | Prioritize multi-source failures and highest-severity events for immediate action while tracking systemic risk across replication subsystems. |
| DC Health Matrix | Score each DC by subsystem health and identify silent or degraded systems quickly while reviewing enterprise-wide health distribution and outliers. |
| Log Volume and Cost | Estimate billed volume trends and projected 30-day cost by source and host to forecast cost exposure and optimize telemetry investment. |

## Workbook Overview Screenshots

### Overview Tab
![Overview Tab - Placeholder 1](https://placehold.co/1600x900?text=Overview+Tab+Screenshot+1)
![Overview Tab - Placeholder 2](https://placehold.co/1600x900?text=Overview+Tab+Screenshot+2)

### DFS Replication Tab
![DFSR Tab - Placeholder 1](https://placehold.co/1600x900?text=DFSR+Tab+Screenshot+1)
![DFSR Tab - Placeholder 2](https://placehold.co/1600x900?text=DFSR+Tab+Screenshot+2)

### File Replication (NTFRS) Tab
![NTFRS Tab - Placeholder 1](https://placehold.co/1600x900?text=NTFRS+Tab+Screenshot+1)
![NTFRS Tab - Placeholder 2](https://placehold.co/1600x900?text=NTFRS+Tab+Screenshot+2)

### Directory Service Tab
![Directory Service Tab - Placeholder 1](https://placehold.co/1600x900?text=Directory+Service+Tab+Screenshot+1)
![Directory Service Tab - Placeholder 2](https://placehold.co/1600x900?text=Directory+Service+Tab+Screenshot+2)

### Security and MDE Tab
![Security and MDE Tab - Placeholder 1](https://placehold.co/1600x900?text=Security+and+MDE+Tab+Screenshot+1)
![Security and MDE Tab - Placeholder 2](https://placehold.co/1600x900?text=Security+and+MDE+Tab+Screenshot+2)

### Critical Events Tab
![Critical Events Tab - Placeholder 1](https://placehold.co/1600x900?text=Critical+Events+Tab+Screenshot+1)
![Critical Events Tab - Placeholder 2](https://placehold.co/1600x900?text=Critical+Events+Tab+Screenshot+2)

### DC Health Matrix Tab
![DC Health Matrix Tab - Placeholder 1](https://placehold.co/1600x900?text=DC+Health+Matrix+Tab+Screenshot+1)
![DC Health Matrix Tab - Placeholder 2](https://placehold.co/1600x900?text=DC+Health+Matrix+Tab+Screenshot+2)

### Log Volume and Cost Tab
![Log Volume and Cost Tab - Placeholder 1](https://placehold.co/1600x900?text=Log+Volume+and+Cost+Tab+Screenshot+1)
![Log Volume and Cost Tab - Placeholder 2](https://placehold.co/1600x900?text=Log+Volume+and+Cost+Tab+Screenshot+2)

## Section Details And What Each One Does

### Overview
- What it does: provides enterprise-level KPI and trend snapshots across DFS Replication, File Replication Service, and Directory Service logs.
- Primary visuals: KPI tiles, event volume timeline, source distribution, severity mix, top DC summary.
- Why it matters: confirms collection coverage and quickly identifies whether replication risk is rising or isolated.

### DFS Replication
- What it does: focuses on DFSR-specific replication failures and service health indicators.
- Primary visuals: critical event ID trends, top impacted DCs, service stop/start/halt timelines, detailed recent error table.
- Why it matters: catches 2213/4012/5002/6016 class failures that can interrupt SYSVOL consistency.

### File Replication (NTFRS)
- What it does: tracks NTFRS health for legacy or transitional environments still relying on FRS behavior.
- Primary visuals: journal wrap and SYSVOL readiness indicators, partner connectivity patterns, critical event reference.
- Why it matters: identifies SYSVOL readiness and partner replication risk where NTFRS is still present.

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
- What it does: produces a per-DC scorecard across DFSR, NTFRS, and Directory Service with an overall health state.
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
  - File Replication Service
  - Directory Service

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

Example commands:

```powershell
cd C:\Users\jobarbar\Defender_XDR
git add Dashboards/SYSVOL-DC-Replication-Monitor/README.md
git commit -m "Add full README page with section details and screenshot placeholders"
git push
```

## Replace Placeholder Screenshots Later
- Upload your real screenshots to GitHub issue attachments or repo assets.
- Replace each placeholder image URL in this README with your final screenshot URL.
- Keep the same headings so the page layout stays clean and consistent.
