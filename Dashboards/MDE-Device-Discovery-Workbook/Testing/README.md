# MDE Device Discovery Workbook Testing

Two PowerShell scripts for end to end testing of the MDE Device Discovery workbook in a lab environment. These are kept in their own folder so the workbook JSON and ARM deploy files stay clean.

## Folder contents

| File | Purpose |
|---|---|
| `New-SyntheticDiscoveredDevices.ps1` | Generates fake devices on the lab subnet so MDE Discovery picks them up and they appear in `DeviceInfo` and `DeviceNetworkInfo`. |
| `New-DeviceDiscoveredDevicesForWorkbook.ps1` | Runs every KQL tile in the workbook against Advanced Hunting and reports PASS / EMPTY / FAIL per tile. |
| `README.md` | This file. |

## Prerequisites

* **On-prem physical Windows host** on a subnet where at least one onboarded MDE device has Standard Discovery enabled. The seeding script refuses to run on Azure VMs, AWS EC2, Hyper-V VMs, VMware VMs, or any virtualized environment.
* PowerShell 5.1 or 7 (run elevated).
* Outbound HTTPS to `login.microsoftonline.com` and `api.security.microsoft.com`.
* An Entra account with Security Reader, Security Administrator, Global Reader, or `AdvancedHunting.Read.All`.
* The MDE Device Discovery workbook deployed to the tenant.

## Where this can run

| Environment | Seeding script | Validator script |
|---|---|---|
| On-prem physical Windows host on **wired Ethernet** | Yes (most reliable) | Yes |
| On-prem physical Windows host on **home or small-office Wi-Fi** | Usually works | Yes |
| On-prem physical Windows host on **corporate Wi-Fi with client isolation** | Often blocked. Multicast and broadcast between Wi-Fi clients are typically dropped by enterprise APs. | Yes |
| On-prem physical Windows host on **guest Wi-Fi** | No | Yes |
| On-prem Hyper-V / VMware / KVM VM | **No** (script aborts) | Yes |
| Azure / AWS / GCP VM | **No** (script aborts) | Yes |

The script auto-detects Wi-Fi adapters and enables a directed-broadcast fallback (e.g. `192.168.50.255`) in addition to multicast, since some enterprise APs forward broadcast even when they block multicast. There is no software workaround if the AP drops both. **For guaranteed results use a wired Ethernet connection on the same flat subnet as the MDE Discovery sensor.**

## Run order

### Step 1. Seed synthetic devices

Run on the lab host that is on the same broadcast domain as a Discovery sensor. The script announces 35 fake devices via mDNS, SSDP, and an HTTP banner.

```powershell
cd .\Testing
.\New-SyntheticDiscoveredDevices.ps1 -BaseIP 192.168.50.100 -DurationMinutes 240
```

Common variations:

```powershell
# Pick a specific NIC if multiple are present
.\New-SyntheticDiscoveredDevices.ps1 -NicAlias "Ethernet" -BaseIP 10.0.50.50 -DurationMinutes 60

# Use a custom profile catalog instead of the built-in 35 profiles
.\New-SyntheticDiscoveredDevices.ps1 -ConfigPath .\my-profiles.json

# Cleanup if a prior run exited abnormally
.\New-SyntheticDiscoveredDevices.ps1 -Cleanup
```

The script:

* Adds temporary IP aliases on the chosen NIC (one per profile).
* Adds Windows Firewall allow rules for UDP 5353, 5355, 137, 1900 and TCP 8080.
* Broadcasts mDNS announcements on `224.0.0.251:5353`.
* Broadcasts SSDP `NOTIFY ssdp:alive` on `239.255.255.250:1900` with vendor and model strings.
* Hosts a small HTTP listener on TCP 8080 returning a UPnP `description.xml` so SSDP `LOCATION:` URLs resolve to a real banner.
* Re announces every 60 seconds (configurable).
* Auto removes IP aliases and firewall rules on Ctrl+C.

Profiles cover every workbook category:

* Workstations (Win11, Win10, macOS, Linux)
* Servers (Windows Server, RHEL, DC)
* Network infrastructure (Palo Alto, Fortinet, Cisco, Aruba, Meraki, Ubiquiti, MikroTik, F5)
* Printers (HP, Xerox, Canon, Brother)
* Cameras (Hikvision, Dahua, Axis, NVR)
* IoT and OT (Schneider BMS, Siemens PLC, Rockwell PLC, Polycom VoIP, Crestron AV, Honeywell thermostat, HID badge reader, Moxa industrial sensor)
* NAS (Synology, QNAP)
* Mobile (iOS, Android) - limited fingerprint surface, may not classify reliably

Vendor and model strings are crafted to match the workbook's classification logic. The IoT vulnerability tile will pick up Hikvision, Siemens, Rockwell, Polycom, MikroTik, etc.

### Step 2. Wait for ingestion

Allow 30 to 60 minutes for MDE Discovery to ingest, classify, and surface the devices in `DeviceInfo` and `DeviceNetworkInfo`. IoT and OT classification can take 1 to 4 hours.

You can confirm progress in Advanced Hunting:

```kql
DeviceInfo
| where Timestamp > ago(2h)
| where DeviceName startswith "LAB-"
| summarize arg_max(Timestamp, *) by DeviceId
| project DeviceName, DeviceType, DeviceSubtype, OnboardingStatus, Vendor, Model, OSPlatform
| order by DeviceName asc
```

### Step 3. Validate workbook tiles

Run from anywhere with internet egress (lab host or your laptop).

```powershell
cd .\Testing
.\New-DeviceDiscoveredDevicesForWorkbook.ps1
```

Variations:

```powershell
# Quick smoke test against last 24 hours
.\New-DeviceDiscoveredDevicesForWorkbook.ps1 -TimeRange 'between (ago(24h) .. now())'

# Full 30 day window
.\New-DeviceDiscoveredDevicesForWorkbook.ps1 -TimeRange 'between (ago(30d) .. now())'

# Skip a slow or noisy tile
.\New-DeviceDiscoveredDevicesForWorkbook.ps1 -Skip 'overview-trend-linechart'

# Reuse an existing token
.\New-DeviceDiscoveredDevicesForWorkbook.ps1 -AccessToken $env:AH_TOKEN
```

Authentication is device code flow against a well known public client. The first run prints a URL and code. Open the URL in any browser and sign in with an account that has Security Reader, Security Administrator, Global Reader, or `AdvancedHunting.Read.All`.

Outputs:

* Console table with `PASS`, `EMPTY`, `FAIL`, row count, and elapsed milliseconds per tile.
* `TestResults\TileResults-<timestamp>.csv` for review.
* `TestResults\TileErrors-<timestamp>.log` with the resolved KQL plus error message for any FAIL.

Advanced Hunting limits per query: 10000 rows max, 10 minute timeout, 100 MB result. A grid expecting 800k devices will return 10000 and report PASS. The workbook itself runs the same queries inside Sentinel or Azure Monitor without those caps.

### Step 4. Eyeball the workbook

Open the workbook in the portal and walk through every tab.

* Overview KPI tiles, subtype pies, top vendors, top SSIDs, daily trend.
* All Devices grid (try different RowLimit values).
* Network Infrastructure, Printers, IoT and OT, Cameras, Computers and Servers tabs.
* IoT vulnerability tile should match Hikvision, Siemens, Rockwell, Polycom, MikroTik based on seeded profiles.

Compare numbers against the Defender portal device inventory for sanity. The portal is cumulative inventory, the workbook tiles are point in time KQL. A 1 to 3 percent delta is normal.

### Step 5. Cleanup

Ctrl+C the seeding script. It removes IP aliases, firewall rules, and the HTTP listener automatically.

If something exits unexpectedly and leaves aliases or firewall rules behind:

```powershell
.\New-SyntheticDiscoveredDevices.ps1 -Cleanup
```

## Important caveats

* **You cannot inject rows into `DeviceInfo` directly via API.** It is a managed Defender table. The seeding script works by putting real network presence on the wire so a Discovery sensor on the same subnet observes the announcements.
* **Multicast does not cross VLANs.** The lab host and at least one onboarded sensor must share a broadcast domain.
* **Do not run on production networks.** The script announces fake hostnames and vendor strings on the wire. Use only on isolated lab subnets.
* **Mobile classification is weak.** Real iOS and Android use specific Bonjour TXT records that the script does not fully replicate. Workstations, servers, network gear, printers, cameras, and IoT or OT classify reliably.
* **Vulnerability matches are pattern based.** The workbook's `_VulnLookup` table is hard coded. The IoT vuln tile flags vendors regardless of firmware version. Use it as a "where to investigate" pointer, not authoritative CVE coverage.

## Sample custom profile JSON

Used with `-ConfigPath`. Same shape as the built in catalog.

```json
[
  {
    "Hostname":   "TEST-CAM-50",
    "DeviceType": "Camera",
    "OS":         "Hikvision IPC",
    "Vendor":     "Hikvision",
    "Model":      "DS-2CD2186G2",
    "SubType":    "IPCamera"
  },
  {
    "Hostname":   "TEST-PLC-51",
    "DeviceType": "IoTDevice",
    "OS":         "Step7",
    "Vendor":     "Siemens",
    "Model":      "S7-1500",
    "SubType":    "PLC"
  }
]
```
