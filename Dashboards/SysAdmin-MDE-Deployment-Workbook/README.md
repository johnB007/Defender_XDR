# SysAdmin MDE Deployment Workbook

## Intro
This package publishes a Microsoft Sentinel workbook for monitoring Microsoft Defender for Endpoint (MDE) deployment health and security posture across your environment.
It is built for day-1 MDE operations with:
- ESS FRAGO-6 compliance tracking against the 30-day last-seen window
- EDR and AV sensor health status with 7-day communication compliance
- EDR/AV installation coverage across all onboarded devices
- Firewall event classification and triage by device
- Threat event summary from Sentinel incidents and alerts
- DLP / USB removable media write activity
- Intune Firewall Policy delivery evidence

## Summary For Sysadmin And Security
This workbook gives sysadmins and SOC analysts a unified view of MDE deployment status and security control compliance.
- Track which devices are compliant with check-in requirements and identify those falling outside the policy window.
- Monitor EDR and AV sensor health to catch silent sensor failures before they create coverage gaps.
- Use the EDR/AV Install Status tab to find devices with partial or missing coverage.

### Tab Breakdown
| Tab | Sysadmin And Security Use |
|---|---|
| Compliance Status | Track ESS FRAGO-6 compliance based on MDE last check-in within 30 days. Pie chart + compliance rate % tile + trend line + detail grid. |
| EDR Sensor Status | Monitor EDR sensor communication health. Devices not seen in 7 days are flagged Noncompliant. |
| AV Sensor Status | Monitor Defender AV process presence. Compliant = MsMpEng.exe / mdatp / wdavdaemon seen within 7 days. |
| EDR/AV Install Status | Cross-reference EDR onboarding and AV telemetry to classify devices as EDR+AV Installed, AV Only, EDR Only, or No Coverage. |
| Firewall Events | View MDE firewall signals classified into Blocked, Allowed, Connection Activity, and Failed Connection. |
| Threat Events | Summarize Sentinel security incidents — total, open, and high severity — with detection source and tactic breakdowns. |
| DLP Events | Detect USB mass storage connections correlated with removable-media file writes. |
| Intune Compliance | Review FW Policy assignment, device sync, and compliance check evidence from IntuneAuditLogs and IntuneDeviceComplianceOrg. |

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
