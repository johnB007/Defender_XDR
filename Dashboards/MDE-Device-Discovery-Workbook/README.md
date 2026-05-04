# MDE Device Discovery and Inventory Workbook

## Intro
This workbook gives you an inventory of devices discovered by Microsoft Defender for Endpoint (MDE) Device Discovery, optimized for environments with very large device counts (hundreds of thousands of endpoints).

The **All Devices** tab is full-scope (managed + unmanaged) so you can compare onboarded vs unmanaged side by side. **Every other category tab is scoped to unmanaged devices only** (devices where `OnboardingStatus` is empty or not `Onboarded`) so SOC and IT teams can focus directly on the onboarding gap.

It includes:
- KPI tiles for unmanaged counts by category, onboarding readiness, exposure, and lifecycle
- Per-category tabs for Audio & Video, Network Infrastructure, Printers & MFPs, IoT & OT, Computers & Servers, and Mobile & Tablets
- Vendor and Model columns on every grid so unmanaged devices can be identified at a glance
- IoT vendor risk heatmap and public-IP exposure grid for OT/IoT triage
- IoT/OT **Vendor-Pattern Vulnerability Matches** section: KPI tiles + grid that pattern-match unmanaged device names against publicly disclosed advisories ([CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog), [CISA ICS Advisories](https://www.cisa.gov/news-events/cybersecurity-advisories?f%5B0%5D=advisory_type%3A95), vendor PSIRTs)
- Computers & Servers onboarding range KPIs (1d / 7d / 30d / 90d) and daily onboarding-trend line

## Summary For Sysadmin And Security
This workbook gives IT and security teams one place to review MDE device discovery data across device categories with an unmanaged-first lens.
- Identify unmanaged or unenrolled devices in each category and prioritize onboarding.
- Surface audio/video devices (cameras, conferencing endpoints, VoIP phones) and IoT/OT devices that have never been formally inventoried.
- Spot OT/IoT devices reachable on public IPs and prioritize them for segmentation.
- Track recent onboarding activity (1d / 7d / 30d / 90d range tiles + daily line chart).
- Export any device grid for vendor conversations, compliance reviews, or field technician work orders.

### Tab Breakdown
| Tab | Sysadmin And Security Use |
|---|---|
| Overview | KPI summary showing both Onboarded and Unmanaged device counts so coverage is visible at a glance. Includes device-type distribution and a network / SSID breakdown by category. |
| All Devices | **Full-scope** inventory grid of every device MDE has discovered (managed and unmanaged), with filters for type, OS, onboarding status, and exposure. Used for managed-vs-unmanaged comparison. Exportable to Excel. |
| Audio & Video | **Unmanaged only.** Scoped inventory of cameras, webcams, video surveillance, and conferencing/AV equipment. Camera Heartbeat and Camera Network Activity sub-tabs help identify silently failing cameras. |
| Network Infrastructure | **Unmanaged only.** Scoped inventory of switches, routers, access points, and network devices with Vendor, Model, OS Version, FirstSeen, DefaultGateway, DnsServers, ConnectedNetworkName, DomainAuthenticated, and IsPublicIP columns. |
| Printers & MFPs | **Unmanaged only.** Scoped inventory of printers and multi-function printers (MFPs). Identify unmanaged print infrastructure with Vendor and Model columns. |
| IoT & OT Devices | **Unmanaged only.** Scoped inventory of IoT devices, smart appliances, VoIP phones, game consoles, and communications devices. Includes Top Vendors chart, Vendor Risk Heatmap (vendor x exposure), Public-IP exposure grid (top 100), and **Vendor-Pattern Vulnerability Matches** (CISA KEV / ICS-CERT / vendor PSIRT pattern-match against unmanaged device names). |
| Computers & Servers | **Unmanaged only.** Scoped inventory of workstations, desktops, laptops, and servers. Includes onboarding range KPIs (1d / 7d / 30d / 90d) and a daily onboarding-trend line chart. |
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


## Section Details And What Each One Does

### Overview
- What it does: pulls KPI counts from DeviceInfo broken into **Onboarded** vs **Unmanaged** so coverage is immediately obvious. Renders device-type distribution and a network / SSID breakdown chart by device category.
- Primary visuals: dual-scope KPI tiles row, device type chart, asset count bar chart, network SSID stacked bar chart, network SSID detail grid.
- Why it matters: gives the SOC and IT team a quick view of onboarding coverage and where unmanaged devices live before drilling into individual tabs.

### All Devices
- What it does: queries DeviceInfo for every discovered device (full scope - managed + unmanaged) and joins with DeviceNetworkInfo to surface the last known IP and connected network. Renders a filterable grid with DeviceName, DeviceType, OS, IP, SSID, OnboardingStatus, SensorHealthState, Vendor, Model, and ExposureLevel columns.
- Primary visuals: full device inventory grid with column filters, Excel export button.
- Why it matters: the only tab that retains managed devices, used for quick lookup and managed-vs-unmanaged comparison.

### Audio & Video (Unmanaged)
- What it does: filters DeviceInfo to `AudioAndVideo` plus legacy values (`Camera`, `Webcam`, `AudioVideoEquipment`, `VideoSurveillance`) and excludes onboarded devices. Includes Camera Heartbeat and Camera Network Activity sub-tabs for silent-failure detection.
- Primary visuals: KPI tiles, filterable device grid with Vendor and Model, camera heartbeat and network activity sub-tabs.
- Why it matters: cameras, conferencing endpoints, and AV gear are often unmanaged or silently offline. This tab shows what MDE sees and which devices need onboarding.

### Network Infrastructure (Unmanaged)
- What it does: filters DeviceInfo to NetworkDevice type and excludes onboarded devices. Detail grid includes Vendor, Model, OSVersion, FirstSeen, DefaultGateway, DnsServers, ConnectedNetworkName, DomainAuthenticated, and IsPublicIP columns from DeviceNetworkInfo.
- Primary visuals: KPI tiles, enriched device grid for switches, routers, and access points.
- Why it matters: unmanaged network gear is a high-impact blind spot. The expanded columns help operations identify ownership and reachability quickly.

### Printers & MFPs (Unmanaged)
- What it does: filters DeviceInfo to `Printer` type plus common printer/MFP hostname patterns (HP, Xerox, Canon, Konica, Kyocera, Ricoh, Brother, Epson, Toshiba, Sharp), excluding onboarded devices.
- Primary visuals: KPI tiles, filterable device grid with Vendor and Model.
- Why it matters: printers often hold sensitive data and rarely get onboarded. This tab gives a reviewable inventory of the unmanaged print fleet.

### IoT & OT Devices (Unmanaged)
- What it does: filters DeviceInfo to IoTDevice, SmartAppliance, CommunicationsDevice, VoIPPhone, GameConsole, MediaPlayer types and OT name patterns (thermostat, hvac, bms, plc, scada, hmi, kiosk, pos-, atm-, etc.), excluding onboarded devices and regular endpoints.
- Primary visuals: KPI tiles (Total / Can Be Onboarded / Insufficient Info / Unsupported), Top Vendors bar chart, Vendor Risk Heatmap (vendor x exposure level), subtype/exposure/onboarding pie charts, full device grid, Public-IP exposure grid (devices reachable on public IPs, derived from DeviceNetworkInfo), and a **Vendor-Pattern Vulnerability Matches** section with Critical/High/Medium/Total KPI tiles and a grid that pattern-matches unmanaged device names against publicly disclosed advisories (CISA KEV, CISA ICS Advisories, vendor PSIRTs).
- Why it matters: IoT and OT devices are typically under-managed and high-risk. The vendor heatmap, public-IP grid, and CISA-anchored vulnerability pattern match provide direct triage signal for segmentation, onboarding, and CISO-level reporting.

### Computers & Servers (Unmanaged)
- What it does: filters DeviceInfo to Workstation, Desktop, Laptop, and Server types. Onboarded views are scoped to Windows OS + active sensor; Unmanaged views show all unmanaged Windows/Server endpoints.
- Primary visuals: KPI tiles, OS distribution pie, sensor-health pie, exposure-level pie, filterable device grid with Vendor and Model, **Onboarding Activity** range KPI tiles (1d / 7d / 30d / 90d), and a **Daily Onboarding Trend** line chart.
- Why it matters: this is the main endpoint coverage view. The range tiles and daily trend line let leadership see recent onboarding momentum and spot regressions without the noise of left-censored first-seen calculations.

### Mobile & Tablets (Unmanaged)
- What it does: filters DeviceInfo to MobilePhone, Smartphone, and Tablet types and excludes onboarded devices.
- Primary visuals: KPI tiles, filterable device grid with Vendor and Model.
- Why it matters: mobile devices that access corporate resources should be enrolled or at least visible. This tab shows unmanaged mobile devices MDE has observed.

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
- If the Audio & Video, Mobile, or IoT tabs show no data, confirm that MDE is reporting `DeviceType` for those assets; some older firmware devices may appear as `Unknown` type and surface in the All Devices tab instead.
