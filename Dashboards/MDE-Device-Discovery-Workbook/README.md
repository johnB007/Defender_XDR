# MDE Device Discovery and Inventory Workbook

## Intro
This workbook provides a **full-spectrum asset inventory** of all devices discovered by Microsoft Defender for Endpoint (MDE) Device Discovery.
It is built for security operations and IT asset management with:
- KPI tiles for total devices, onboarded vs unmanaged, sensor health, and criticality breakdown
- Per-category tabs scoped to Cameras, Network Infrastructure, Printers, IoT/OT, Computers & Servers, and Mobile & Tablets
- Full device grids with OS, IP, last seen, onboarding status, and risk signal columns — all exportable to Excel
- Network / SSID inventory showing every discovered network with device category breakdowns
- Network Context tab classifying every device as Corporate (Domain Authenticated), Likely Home Network, or Public / Internet-Facing
- Risk Signals grid flagging non-mobile corporate assets found on home or public networks

## Summary For Sysadmin And Security
This workbook gives IT and security teams a single pane of glass for MDE device discovery — covering every device category from cameras and IP phones to workstations and servers.
- Identify unmanaged or unenrolled devices in each category and prioritize onboarding.
- Surface surveillance cameras, VoIP phones, and IoT devices on corporate SSIDs that have never been formally inventoried.
- Flag endpoints seen on home or public networks that should only appear on corporate infrastructure.
- Export any device grid for vendor conversations, compliance reviews, or field technician work orders.

### Tab Breakdown
| Tab | Sysadmin And Security Use |
|---|---|
| Overview | KPI summary of total discovered devices broken down by type, onboarding status, and sensor health. Includes a network / SSID chart showing device categories per network sorted by total device count. |
| All Devices | Full inventory grid of every device MDE has discovered, with filters for type, OS, onboarding status, and risk level. Exportable to Excel. |
| Cameras & Physical Sec | Scoped inventory of cameras, webcams, video surveillance, and audio/video equipment. Includes KPI tiles for total, onboarded, and unenrolled counts. |
| Network Infrastructure | Scoped inventory of switches, routers, access points, and network devices. Shows onboarding posture and sensor health per device. |
| Printers & MFDs | Scoped inventory of printers and multi-function devices. Identify unmanaged print infrastructure and correlate with SSID context. |
| IoT & OT Devices | Scoped inventory of IoT devices, smart appliances, VoIP phones, game consoles, and communication devices. |
| Computers & Servers | Scoped inventory of workstations, desktops, laptops, and servers. Includes OS platform, onboarding status, and criticality. |
| Mobile & Tablets | Scoped inventory of mobile phones, smartphones, and tablets discovered by MDE. |
| Network Context | Classifies every device as Corporate (Domain Authenticated), Corporate (Private — Enterprise), Likely Home Network, or Public / Internet-Facing. Risk Signals grid below flags non-mobile corporate assets seen on home or public networks. |

## Workbook Overview Screenshots

### Overview Tab
> _Screenshot — add after first deployment_

### All Devices Tab
> _Screenshot — add after first deployment_

### Cameras & Physical Sec Tab
> _Screenshot — add after first deployment_

### Network Infrastructure Tab
> _Screenshot — add after first deployment_

### Printers & MFDs Tab
> _Screenshot — add after first deployment_

### IoT & OT Devices Tab
> _Screenshot — add after first deployment_

### Computers & Servers Tab
> _Screenshot — add after first deployment_

### Mobile & Tablets Tab
> _Screenshot — add after first deployment_

### Network Context Tab
> _Screenshot — add after first deployment_

## Section Details And What Each One Does

### Overview
- What it does: pulls KPI counts from DeviceInfo for total discovered devices, onboarded devices, unenrolled devices, devices with sensor issues, and high/medium/low criticality assets. Renders a stacked bar chart for device type distribution and a network / SSID breakdown chart sorted by total device count (largest network leftmost).
- Primary visuals: KPI tiles row, device type donut chart, asset count bar chart, network SSID stacked bar chart (by category), network SSID detail grid.
- Why it matters: gives the SOC and IT team an immediate at-a-glance posture snapshot without opening individual device tabs.

### All Devices
- What it does: queries DeviceInfo for every discovered device and joins with DeviceNetworkInfo to surface the last known IP and connected network. Renders a full filterable grid with DeviceName, DeviceType, OS, IP, SSID, OnboardingStatus, SensorHealthState, and RiskScore columns.
- Primary visuals: full device inventory grid with column filters, Excel export button.
- Why it matters: the master inventory view — use it for compliance exports, onboarding gap analysis, and rapid lookup of any specific device.

### Cameras & Physical Sec
- What it does: filters DeviceInfo to DeviceType in Camera, Webcam, AudioVideoEquipment, and VideoSurveillance categories. Shows KPI tiles for total count, onboarded, unenrolled, and sensor health, then a full device grid.
- Primary visuals: four KPI tiles, filterable device grid with last seen timestamp and network context.
- Why it matters: physical security cameras are frequently unmanaged and undocumented — this tab surfaces every camera MDE has discovered and shows which ones are not enrolled in any EDR.

### Network Infrastructure
- What it does: filters DeviceInfo to NetworkDevice type. Shows KPI tiles and a full grid of all switches, routers, and access points discovered by MDE passive and active discovery.
- Primary visuals: KPI tiles, device grid with OS and firmware context where available.
- Why it matters: unmanaged network devices are a high-value target for attackers — this tab identifies every network device visible to MDE and flags gaps in coverage.

### Printers & MFDs
- What it does: filters DeviceInfo to Printer type. Shows KPI tiles for total, onboarded, and unenrolled counts, and a full grid with last seen IP and network association.
- Primary visuals: KPI tiles, filterable device grid.
- Why it matters: printers are rarely onboarded to EDR solutions and often hold cached credentials and scanned documents — this tab surfaces the full print fleet for security review.

### IoT & OT Devices
- What it does: filters DeviceInfo to IoTDevice, SmartAppliance, CommunicationsDevice, VoIPPhone, GameConsole, and MediaPlayer types. Shows KPI tiles and a full inventory grid.
- Primary visuals: KPI tiles, device grid with type, OS, and network context columns.
- Why it matters: IoT and OT devices are the most common unmanaged attack surface in enterprise networks — this tab gives the full picture of everything MDE has discovered in these categories.

### Computers & Servers
- What it does: filters DeviceInfo to Workstation, Desktop, Laptop, and Server types. Shows KPI tiles for total count, onboarded, unenrolled, and by OS platform, then a full grid.
- Primary visuals: KPI tiles, OS platform breakdown, filterable device grid with criticality and onboarding status.
- Why it matters: primary endpoint coverage view for the IT team — quickly identify workstations and servers that are not yet onboarded to MDE.

### Mobile & Tablets
- What it does: filters DeviceInfo to MobilePhone, Smartphone, and Tablet types. Shows KPI tiles and a full grid with last seen details.
- Primary visuals: KPI tiles, filterable device grid.
- Why it matters: mobile devices accessing corporate resources should be enrolled or at minimum visible — this tab surfaces any mobile device MDE has observed on the network.

### Network Context
- What it does: joins DeviceNetworkInfo with DeviceInfo and classifies every device based on IP range and domain authentication status into Corporate (Domain Authenticated), Corporate (Private — Enterprise), Likely Home Network, or Public / Internet-Facing. A Risk Signals grid below filters to non-mobile corporate assets found on Home or Public networks.
- Primary visuals: device classification grid with IP, gateway, network name, and domain auth columns; Risk Signals grid scoped to anomalous network placement.
- Why it matters: immediately surfaces endpoints operating outside expected network boundaries — a workstation on a home network SSID or a server with a public IP are high-priority investigation items.

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
- Active discovery may generate additional network traffic — review your MDE Device Discovery settings before enabling in sensitive OT/ICS environments.
- If the Cameras, Mobile, or IoT tabs show no data, confirm that MDE is reporting `DeviceType` for those assets; some older firmware devices may appear as `Unknown` type and surface in the All Devices tab instead.
