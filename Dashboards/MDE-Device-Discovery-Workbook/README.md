# MDE Device Discovery and Inventory Workbook

## Intro
This workbook gives you an inventory of devices discovered by Microsoft Defender for Endpoint (MDE) Device Discovery.

It includes:
- KPI tiles for total devices, onboarding state, sensor health, and exposure level
- Per-category tabs for Audio & Video, Network Infrastructure, Printers & MFPs, IoT/OT, Computers & Servers, and Mobile & Tablets
- Device grids with OS, IP, last seen, onboarding status, and risk-related fields
- Network and SSID views that show where discovered devices are connected
- A Network Context tab that classifies devices as Corporate, Home, Public, or Unknown Private
- A Risk Signals grid for non-mobile corporate assets seen on home or public networks

## Summary For Sysadmin And Security
This workbook gives IT and security teams one place to review MDE device discovery data across device categories.
- Identify unmanaged or unenrolled devices in each category and prioritize onboarding.
- Surface audio/video devices (cameras, conferencing endpoints, VoIP phones) and IoT devices on corporate SSIDs that have never been formally inventoried.
- Flag endpoints seen on home or public networks that should only appear on corporate infrastructure.
- Export any device grid for vendor conversations, compliance reviews, or field technician work orders.

### Tab Breakdown
| Tab | Sysadmin And Security Use |
|---|---|
| Overview | KPI summary of total discovered devices broken down by type, onboarding status, and sensor health. Includes a network / SSID chart showing device categories per network sorted by total device count. |
| All Devices | Full inventory grid of every device MDE has discovered, with filters for type, OS, onboarding status, and risk level. Exportable to Excel. |
| Audio & Video | Scoped inventory of devices XDR classifies as `AudioAndVideo` - cameras, webcams, video surveillance, and conferencing/AV equipment. Includes KPI tiles for total, onboarded, and unenrolled counts. |
| Network Infrastructure | Scoped inventory of switches, routers, access points, and network devices. Shows onboarding posture and sensor health per device. |
| Printers & MFPs | Scoped inventory of printers and multi-function printers (MFPs). Identify unmanaged print infrastructure and correlate with SSID context. |
| IoT & OT Devices | Scoped inventory of IoT devices, smart appliances, VoIP phones, game consoles, and communication devices. |
| Computers & Servers | Scoped inventory of workstations, desktops, laptops, and servers. Includes OS platform, onboarding status, and criticality. |
| Mobile & Tablets | Scoped inventory of mobile phones, smartphones, and tablets discovered by MDE. |
| Network Context | Classifies every device as Corporate (Domain Authenticated), Corporate (Private - Enterprise), Likely Home Network, or Public / Internet-Facing. Risk Signals grid below flags non-mobile corporate assets seen on home or public networks. |

## Workbook Overview Screenshots

### Overview Tab
<img width="1882" height="671" alt="image" src="https://github.com/user-attachments/assets/8106a59b-bff6-4e01-80c4-b2b2ce4f76ab" />
<img width="1871" height="803" alt="image" src="https://github.com/user-attachments/assets/70aaf7fb-c8d7-4305-84f8-e1700847879e" />
<img width="1877" height="821" alt="image" src="https://github.com/user-attachments/assets/f6ce088a-55ee-451f-beb1-6bbaaff0ad93" />
<img width="1881" height="396" alt="image" src="https://github.com/user-attachments/assets/3857d564-cf7d-4aa8-9918-b9fc1fbc9052" />

### All Devices Tab
<img width="1876" height="802" alt="image" src="https://github.com/user-attachments/assets/a58cd8cb-e852-406b-a5a1-76fc5263bf25" />


### Audio & Video Tab
> _Screenshot placeholder. Add after first deployment._

### Network Infrastructure Tab
<img width="1883" height="812" alt="image" src="https://github.com/user-attachments/assets/475a2be3-6b3d-4c84-85af-3a3d425ab0e5" />


### Printers & MFPs Tab
> _Screenshot placeholder. Add after first deployment._

### IoT & OT Devices Tab
<img width="1890" height="813" alt="image" src="https://github.com/user-attachments/assets/7e42e482-664b-4fe9-b75f-6c2d2bcfd777" />


### Computers & Servers Tab
<img width="1881" height="820" alt="image" src="https://github.com/user-attachments/assets/805af6d7-3d27-4011-9d9a-7c56164306ef" />


### Mobile & Tablets Tab
<img width="1890" height="812" alt="image" src="https://github.com/user-attachments/assets/008539a1-cb71-4a83-b080-566c24462103" />


### Network Context Tab
<img width="1864" height="713" alt="image" src="https://github.com/user-attachments/assets/8e9262c8-6b4e-4837-b7b7-f3137ec9aed2" />


## Section Details And What Each One Does

### Overview
- What it does: pulls KPI counts from DeviceInfo for total discovered devices, onboarded devices, unenrolled devices, devices with sensor issues, and high, medium, and low exposure assets. Renders a stacked bar chart for device type distribution and a network or SSID breakdown chart sorted by total device count.
- Primary visuals: KPI tiles row, device type donut chart, asset count bar chart, network SSID stacked bar chart (by category), network SSID detail grid.
- Why it matters: gives the SOC and IT team a quick summary before drilling into the individual tabs.

### All Devices
- What it does: queries DeviceInfo for every discovered device and joins with DeviceNetworkInfo to surface the last known IP and connected network. Renders a full filterable grid with DeviceName, DeviceType, OS, IP, SSID, OnboardingStatus, SensorHealthState, and RiskScore columns.
- Primary visuals: full device inventory grid with column filters, Excel export button.
- Why it matters: this is the main inventory view for exports, onboarding gap review, and quick lookup of specific devices.

### Audio & Video
- What it does: filters DeviceInfo to DeviceType in `AudioAndVideo` (the official XDR classification for this category), plus broader matches on `Camera`, `Webcam`, `AudioVideoEquipment`, and `VideoSurveillance` for legacy values. Shows KPI tiles for total count, onboarded, unenrolled, and sensor health, then a full device grid.
- Primary visuals: four KPI tiles, filterable device grid with last seen timestamp and network context.
- Why it matters: cameras, conferencing endpoints, and other AV gear are often unmanaged or undocumented. This tab helps identify them and shows which ones are not enrolled in MDE.

### Network Infrastructure
- What it does: filters DeviceInfo to NetworkDevice type. Shows KPI tiles and a full grid of all switches, routers, and access points discovered by MDE passive and active discovery.
- Primary visuals: KPI tiles, device grid with OS and firmware context where available.
- Why it matters: unmanaged network devices are common blind spots. This tab identifies what MDE can see and highlights coverage gaps.

### Printers & MFPs
- What it does: filters DeviceInfo to `Printer` type plus common printer, copier, and MFP hostname patterns (HP, Xerox, Canon, Konica, Kyocera, Ricoh, Brother, Epson, Toshiba, Sharp). Shows KPI tiles for total, onboarded, and unenrolled counts, and a full grid with last seen IP and network association.
- Primary visuals: KPI tiles, filterable device grid.
- Why it matters: printers and multi-function printers are often unmanaged and can store sensitive data. This tab gives you a reviewable inventory of the print fleet.

### IoT & OT Devices
- What it does: filters DeviceInfo to IoTDevice, SmartAppliance, CommunicationsDevice, VoIPPhone, GameConsole, and MediaPlayer types. Shows KPI tiles and a full inventory grid.
- Primary visuals: KPI tiles, device grid with type, OS, and network context columns.
- Why it matters: IoT and OT devices are commonly under-managed. This tab helps you review what MDE has discovered in those categories.

### Computers & Servers
- What it does: filters DeviceInfo to Workstation, Desktop, Laptop, and Server types. Shows KPI tiles for total count, onboarded, unenrolled, and by OS platform, then a full grid.
- Primary visuals: KPI tiles, OS platform breakdown, filterable device grid with criticality and onboarding status.
- Why it matters: this is the main endpoint coverage view for workstations and servers that are not yet onboarded to MDE.

### Mobile & Tablets
- What it does: filters DeviceInfo to MobilePhone, Smartphone, and Tablet types. Shows KPI tiles and a full grid with last seen details.
- Primary visuals: KPI tiles, filterable device grid.
- Why it matters: mobile devices that access corporate resources should be enrolled or at least visible. This tab shows mobile devices MDE has observed on the network.

### Network Context
- What it does: joins DeviceNetworkInfo with DeviceInfo and classifies every device based on IP range and domain authentication status into Corporate (Domain Authenticated), Corporate (Private - Enterprise), Likely Home Network, or Public / Internet-Facing. A Risk Signals grid below filters to non-mobile corporate assets found on Home or Public networks.
- Primary visuals: device classification grid with IP, gateway, network name, and domain auth columns; Risk Signals grid scoped to anomalous network placement.
- Why it matters: highlights endpoints operating outside expected network boundaries, such as a workstation on a home SSID or a server with a public IP.

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
