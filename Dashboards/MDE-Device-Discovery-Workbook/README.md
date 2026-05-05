# MDE Device Discovery and Inventory Workbook

## Intro
This workbook is an inventory of devices discovered by Microsoft Defender for Endpoint (MDE) Device Discovery, built for environments with hundreds of thousands of endpoints.

The **All Devices** tab is full scope (managed and unmanaged). Every other category tab is scoped to unmanaged devices only (devices where `OnboardingStatus` is empty or not `Onboarded`) so SOC and IT teams can focus on the onboarding gap.

It includes:
- KPI tiles for unmanaged counts by category, onboarding readiness, exposure, and lifecycle
- Per category tabs for Audio & Video, Network Infrastructure, Printers & MFPs, IoT & OT, Computers & Servers, and Mobile & Tablets
- Vendor and Model columns on every grid
- IoT vendor risk heatmap, Top Vendors by Public IP Exposure chart, and Public IP exposure grid for OT/IoT triage
- IoT/OT **Vendor Pattern Vulnerability Matches** section: KPI tiles and a grid that pattern match unmanaged device names against publicly disclosed advisories ([CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog), [CISA ICS Advisories](https://www.cisa.gov/news-events/cybersecurity-advisories?f%5B0%5D=advisory_type%3A95), vendor PSIRTs)
- Computers & Servers KPI tiles and a daily onboarding trend line bucketed into Workstations / Servers / Other Endpoints

## Summary For Sysadmin And Security
Use this workbook to review MDE device discovery data across device categories with an unmanaged first lens.
- Identify unmanaged or unenrolled devices in each category and prioritize onboarding.
- Surface audio and video devices (cameras, conferencing endpoints, VoIP phones) and IoT/OT devices that have never been formally inventoried.
- Find OT/IoT devices reachable on public IPs and prioritize them for segmentation.
- Review recent onboarding activity (1d / 7d / 30d / 90d range tiles and a daily line chart).
- Export any device grid for vendor conversations, compliance reviews, or field technician work orders.

### Tab Breakdown
| Tab | Sysadmin And Security Use |
|---|---|
| Overview | KPI summary showing both Onboarded and Unmanaged device counts. Includes device type distribution and a network and SSID breakdown by category. |
| All Devices | **Full scope** inventory grid of every device MDE has discovered (managed and unmanaged), with filters for type, OS, onboarding status, and exposure. Use this tab for managed vs unmanaged comparison. Exportable to Excel. |
| Audio & Video | **Unmanaged only.** Scoped inventory of cameras, webcams, video surveillance, and conferencing or AV equipment. Camera Heartbeat and Camera Network Activity sub tabs identify silently failing cameras. |
| Network Infrastructure | **Unmanaged only.** Scoped inventory of switches, routers, access points, and network devices with Vendor, Model, OS Version, FirstSeen, DefaultGateway, DnsServers, ConnectedNetworkName, DomainAuthenticated, and IsPublicIP columns. |
| Printers & MFPs | **Unmanaged only.** Scoped inventory of printers and multi function printers (MFPs) with Vendor and Model columns. |
| IoT & OT Devices | **Unmanaged only.** Scoped inventory of IoT devices, smart appliances, VoIP phones, game consoles, and communications devices. Includes Top Vendors chart, Top Vendors by Public IP Exposure, Vendor Risk Heatmap (vendor x exposure), Public IP exposure grid (top 100), and **Vendor Pattern Vulnerability Matches** (CISA KEV, ICS CERT, and vendor PSIRT pattern match against unmanaged device names). |
| Computers & Servers | Includes Onboarded and Unmanaged KPI tiles bucketed into Workstations / Servers / Other Endpoints, plus a daily onboarding trend line chart with the same three buckets so weekend bulk onboards of any device class are visible. |
| Mobile & Tablets | **Unmanaged only.** Scoped inventory of mobile phones, smartphones, and tablets discovered by MDE. |

## Workbook Overview Screenshots

### Overview Tab
<img width="1882" height="671" alt="image" src="https://github.com/user-attachments/assets/8106a59b-bff6-4e01-80c4-b2b2ce4f76ab" />
<img width="1871" height="803" alt="image" src="https://github.com/user-attachments/assets/70aaf7fb-c8d7-4305-84f8-e1700847879e" />
<img width="1877" height="821" alt="image" src="https://github.com/user-attachments/assets/f6ce088a-55ee-451f-beb1-6bbaaff0ad93" />
<img width="1881" height="396" alt="image" src="https://github.com/user-attachments/assets/3857d564-cf7d-4aa8-9918-b9fc1fbc9052" />

### All Devices Tab
<img width="1876" height="802" alt="image" src="https://github.com/user-attachments/assets/a58cd8cb-e852-406b-a5a1-76fc5263bf25" />


### Audio & Video Tab
<img width="2017" height="1052" alt="image" src="https://github.com/user-attachments/assets/8a8425d2-f5df-4b5d-86f9-5e4e14096e7c" />

### Network Infrastructure Tab
<img width="2100" height="1010" alt="image" src="https://github.com/user-attachments/assets/3d3f143b-ad77-4503-a167-fe805b9407ee" />

### Printers & MFPs Tab
<img width="1942" height="988" alt="image" src="https://github.com/user-attachments/assets/d30a0048-bb3d-455f-ba85-4fb97c9bf57e" />

### IoT & OT Devices Tab
<img width="1890" height="813" alt="image" src="https://github.com/user-attachments/assets/7e42e482-664b-4fe9-b75f-6c2d2bcfd777" />


### Computers & Servers Tab
<img width="1881" height="820" alt="image" src="https://github.com/user-attachments/assets/805af6d7-3d27-4011-9d9a-7c56164306ef" />


### Mobile & Tablets Tab
<img width="1890" height="812" alt="image" src="https://github.com/user-attachments/assets/008539a1-cb71-4a83-b080-566c24462103" />


## Section Details

### Overview
- What it does: pulls KPI counts from DeviceInfo split into **Onboarded** and **Unmanaged**. Renders device type distribution and a network and SSID breakdown by device category.
- Visuals: dual scope KPI tiles row, device type chart, asset count bar chart, network SSID stacked bar chart, network SSID detail grid.

### All Devices
- What it does: queries DeviceInfo for every discovered device (full scope, managed and unmanaged) and joins DeviceNetworkInfo to surface the last known IP and connected network. Renders a filterable grid with DeviceName, DeviceType, OS, IP, SSID, OnboardingStatus, SensorHealthState, Vendor, Model, and ExposureLevel columns.
- Visuals: full device inventory grid with column filters, Excel export button.
- This is the only tab that retains managed devices.

### Audio & Video (Unmanaged)
- What it does: filters DeviceInfo to `AudioAndVideo` plus legacy values (`Camera`, `Webcam`, `AudioVideoEquipment`, `VideoSurveillance`) and excludes onboarded devices. Includes Camera Heartbeat and Camera Network Activity sub tabs.
- Visuals: KPI tiles, filterable device grid with Vendor and Model, camera heartbeat and network activity sub tabs.

### Network Infrastructure (Unmanaged)
- What it does: filters DeviceInfo to NetworkDevice type and excludes onboarded devices. Detail grid includes Vendor, Model, OSVersion, FirstSeen, DefaultGateway, DnsServers, ConnectedNetworkName, DomainAuthenticated, and IsPublicIP columns from DeviceNetworkInfo.
- Visuals: KPI tiles, device grid for switches, routers, and access points.

### Printers & MFPs (Unmanaged)
- What it does: filters DeviceInfo to `Printer` type plus common printer and MFP hostname patterns (HP, Xerox, Canon, Konica, Kyocera, Ricoh, Brother, Epson, Toshiba, Sharp), excluding onboarded devices.
- Visuals: KPI tiles, filterable device grid with Vendor and Model.

### IoT & OT Devices (Unmanaged)
- What it does: filters DeviceInfo to IoTDevice, SmartAppliance, CommunicationsDevice, VoIPPhone, GameConsole, MediaPlayer types and OT name patterns (thermostat, hvac, bms, plc, scada, hmi, kiosk, pos, atm, etc.), excluding onboarded devices and regular endpoints.
- Visuals: KPI tiles (Total / Insufficient Info / Unsupported), Sub-Type pie, Exposure Level pie, **Top Vendors by Public IP Exposure** bar chart, Top 15 Vendors bar chart, Vendor Risk Heatmap (vendor x exposure level), full device grid, Public IP exposure grid (devices reachable on public IPs, derived from DeviceNetworkInfo), and a **Vendor Pattern Vulnerability Matches** section with Critical / High / Medium / Total KPI tiles and a grid that pattern matches unmanaged device names against publicly disclosed advisories (CISA KEV, CISA ICS Advisories, vendor PSIRTs).

### Computers & Servers
- What it does: queries DeviceInfo for all device types and buckets each device into Workstations (Workstation/Desktop/Laptop, Windows 10/11, macOS, Linux), Servers (`OSPlatform has 'Server'` or `DeviceType =~ 'Server'`), or Other Endpoints (everything else: phones, tablets, IoT, network gear, printers, etc.).
- Visuals: KPI tiles, OS distribution pie, sensor health pie, exposure level pie, filterable device grid with Vendor and Model, **Distinct Devices in Selected Time Range** tiles (Onboarded x 3 buckets and Unmanaged x 3 buckets), and a **Daily Onboarded Reporting Trend** line chart with the same three buckets so weekend bulk onboards across any device class are visible.

### Mobile & Tablets (Unmanaged)
- What it does: filters DeviceInfo to MobilePhone, Smartphone, and Tablet types and excludes onboarded devices.
- Visuals: KPI tiles, filterable device grid with Vendor and Model.

## Prerequisites
- A Log Analytics workspace with MDE data connected (via Microsoft Defender XDR connector or direct MDE log forwarding)
- Read access to the `DeviceInfo` and `DeviceNetworkInfo` tables
- Azure Monitor Workbooks contributor permissions to import and save the workbook

## The Structure
This folder contains:
- `MDE-Device-Discovery-Inventory.json`: workbook JSON payload for manual import via Advanced Editor
- `azuredeploy.json`: one-click ARM deployment template

## How To Deploy
Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FMDE-Device-Discovery-Workbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FMDE-Device-Discovery-Workbook%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- `workspaceName`: your Log Analytics workspace name (default: `SOC-Central`)
- `workbookDisplayName`: display name shown in Azure Monitor / Sentinel (default: `MDE Device Discovery and Inventory Workbook`)
- `workbookId`: leave the default generated value, or provide your own GUID to update an existing instance

### Deployment Note
Azure workbook resources require the underlying resource name to be a GUID. The friendly workbook title comes from `workbookDisplayName`.

## Manual Import (Portal)
1. Go to Microsoft Sentinel or Azure Monitor in your target workspace.
2. Select **Workbooks**, then **New** (or **Add workbook**).
3. Open **Advanced Editor** (the `</>` icon).
4. Paste the contents of `MDE-Device-Discovery-Inventory.json`.
5. Apply and Save.

## Notes
- MDE Device Discovery must be enabled on at least one onboarded device to populate `DeviceNetworkInfo` with passive discovery data.
- Active discovery may generate additional network traffic. Review your MDE Device Discovery settings before enabling it in sensitive OT or ICS environments.
- If the Audio & Video, Mobile, or IoT tabs show no data, confirm that MDE is reporting `DeviceType` for those assets. Some older firmware devices may appear as `Unknown` type and surface in the All Devices tab instead.
