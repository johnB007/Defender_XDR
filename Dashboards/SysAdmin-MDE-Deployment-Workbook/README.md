# SysAdmin MDE Deployment Workbook

## Intro
This package publishes a Microsoft Sentinel workbook focused on SysAdmin and MDE operational visibility.

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
- workspaceName: SOC-Central (or your target workspace name)
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
