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
| On-prem physical Windows host on **wired Ethernet** | **Yes (strongly recommended)** | Yes |
| On-prem physical Windows host on **home or small-office Wi-Fi** | Sometimes — many Wi-Fi drivers do not loopback the host's own multicast back to its own listener, so a single-host setup will not see itself. A *separate* onboarded sensor on the same SSID/broadcast domain works. | Yes |
| On-prem physical Windows host on **corporate Wi-Fi with client isolation** | Often blocked. Multicast and broadcast between Wi-Fi clients are typically dropped by enterprise APs. | Yes |
| On-prem physical Windows host on **guest Wi-Fi** | No | Yes |
| On-prem Hyper-V / VMware / KVM VM | **No** (script aborts) | Yes |
| Azure / AWS / GCP VM | **No** (script aborts) | Yes |

The script auto-detects Wi-Fi adapters and enables a directed-broadcast fallback (the subnet's `.255` address) in addition to multicast, since some enterprise APs forward broadcast even when they block multicast. There is no software workaround if the AP drops both. **For reliable single-host results use a wired Ethernet connection on the same flat subnet as the MDE Discovery sensor.**

> **Why wired matters even on permissive Wi-Fi**: most Wi-Fi NIC drivers do not deliver a host's own outbound multicast packets back to the same host's listening sockets. Wired Ethernet does. When the seeding host is *also* the Discovery sensor, only Ethernet guarantees the host can hear itself. If you have a second onboarded device on the same broadcast domain, Wi-Fi can work because *that* device receives the multicast normally.

## Run order

### Step 0. Pre-flight (do this once per host)

A few small environment checks save a lot of "why aren't devices showing up" time later. All of these are run on the **seeding host**.

**1. Confirm MDE Device Discovery is configured.**
In the Defender portal: `Settings → Device discovery → Discovery setup`.

* Mode = **Standard discovery** (Basic does not ingest mDNS/SSDP advertisements).
* The seeding host's subnet is in **Monitored networks** (not *Ignore* / *No decision*).
* The seeding host is **not excluded** from acting as a discovery sensor.

**2. If the host is dual-homed (Ethernet + Wi-Fi), prefer Ethernet.**
Windows multicast routing follows the interface metric, *not* the script's `-NicAlias` parameter. If Wi-Fi has a lower metric, multicast goes out Wi-Fi regardless of which NIC the script reports it picked. Lower the Ethernet metric so Ethernet wins:

```powershell
Set-NetIPInterface -InterfaceAlias 'Ethernet'  -InterfaceMetric 5
Set-NetIPInterface -InterfaceAlias 'Wi-Fi'     -InterfaceMetric 100
Get-NetIPInterface -AddressFamily IPv4 |
    Where-Object ConnectionState -eq Connected |
    Sort-Object InterfaceMetric |
    Format-Table InterfaceAlias, InterfaceMetric, ConnectionState
```

Use whatever your wired adapter is actually named (`Ethernet`, `Ethernet 2`, etc.).

**3. Free up TCP 8080 if possible (optional).**
If port 8080 is in use the script falls back to 8081 and prints a warning — that is fine and does not affect discovery.

**4. Do not disable the NIC the script is bound to mid-run.**
The script reads the NIC and host IP once at startup and binds its multicast/broadcast sockets to that interface. If you later disable that NIC (e.g. turning Wi-Fi off after the script started on Wi-Fi), announcements silently stop even though the tick counter keeps incrementing. Stop with Ctrl+C, change network state, then restart.

**5. The seeding host cannot be the only onboarded MDE Windows device on the subnet.**
MDE Device Discovery only ingests an mDNS/SSDP announcement when an onboarded *Windows* device on the same broadcast domain witnesses it. The sensor explicitly excludes locally-originated traffic from the host that emitted it (to prevent feedback loops). If the seeding host is the only onboarded Windows device on its subnet, transmission can be 100% healthy on the wire and `DeviceInfo` will still be empty.

Quick check — count onboarded Windows witnesses on your seeding host's subnet:

```kql
DeviceNetworkInfo
| where Timestamp > ago(24h)
| extend IPs = parse_json(IPAddresses)
| mv-expand IPs
| extend IP = tostring(IPs.IPAddress)
| where IP startswith "<your subnet prefix, e.g. 10.0.0.>"
| join kind=inner (
    DeviceInfo
    | where Timestamp > ago(24h)
    | where OnboardingStatus == "Onboarded" and OSPlatform startswith "Windows"
    | summarize arg_max(Timestamp, *) by DeviceId
  ) on DeviceId
| summarize arg_max(Timestamp, *) by DeviceId
| project DeviceName, IP, OSPlatform
```

If this returns one row and that row is the seeding host itself, ingestion will not happen until you add a second onboarded Windows device on the same L2 (a spare laptop, a bridged Hyper-V VM, etc.). Linux MDE agents and *discovered* (unmanaged) devices do **not** count as witnesses.

When the seeding host runs on a Hyper-V vSwitch (so a guest VM can act as the witness), see the next subsection.

### About VIRTUAL-ONLY vs `-AddIPAliases` mode

The default mode (no `-AddIPAliases`) is what the banner calls `Mode: VIRTUAL-ONLY`. The synthetic IPs appear *only inside the mDNS/SSDP payloads* — the script never adds those addresses to the host NIC. End-to-end testing has shown that this mode is sometimes **not sufficient** for MDE Discovery to create new device records, especially when the witness sensor performs L2 reachability checks (ARP) before promoting an announcement to a `DeviceInfo` row. If the synthetic IPs do not exist on any real NIC, ARP for them returns nothing and the announcement may be discarded as unverifiable.

If VIRTUAL-ONLY mode produces zero ingestion after a witness has been confirmed, retry with `-AddIPAliases` on lab hardware that tolerates secondary IPv4 addresses (see safety notes in Step 1). Surface dock USB-Ethernet, Marvell Wi-Fi, and managed-endpoint configurations are the common cases where `-AddIPAliases` is rejected by the OS — on those, you generally cannot get past VIRTUAL-ONLY without changing hardware.

### Running the seeding script through a Hyper-V External vSwitch (witness pattern)

If the only spare Windows machine you have is a Hyper-V VM, you can use it as the witness while the *physical* host runs the seeding script. Both must end up on the same L2.

1. **Create an External virtual switch** (Virtual Switch Manager → New → External). Bind it to the **wired** physical NIC. Leave *Allow management OS to share this network adapter* checked. Leave VLAN ID **unchecked** unless your physical network uses VLAN tagging.
2. **Move the witness VM** to that switch (VM Settings → Network Adapter → Virtual switch → your new External switch). Inside the VM, `ipconfig /release; ipconfig /renew`. Confirm a DHCP lease in the host's real subnet.
3. **Run the seeding script on the host.** After creating the External switch, the host's IP migrates from the physical NIC's alias (e.g. `Ethernet 2`) to a virtual NIC named `vEthernet (<switch name>)`. The script's pre-flight rejects virtual NICs by default — see the troubleshooting table for the override.
4. Confirm the witness VM is reporting from the host subnet in `DeviceNetworkInfo` before counting on ingestion.

> Note: bridging a domain controller VM onto a home or office LAN exposes AD ports (Kerberos, LDAP, DNS, SMB) to that LAN. Do not do this with a DC unless that is acceptable for your lab — use a non-domain-joined Windows VM as the witness instead.

### Step 1. Seed synthetic devices

Run on the lab host that is on the same broadcast domain as a Discovery sensor. The script announces synthetic devices via mDNS and SSDP. By default it runs in **virtual-only mode**: synthetic device IPs appear only inside the announcement payloads, and **the script does not modify the NIC at all**. This is the safest mode and works on hosts where Windows refuses to add a manual IPv4 to a DHCP interface (some endpoint-management policies, certain USB GbE drivers, and some Wi-Fi drivers).

```powershell
# Open PowerShell as Administrator
cd .\Testing
.\New-SyntheticDiscoveredDevices.ps1 -DurationMinutes 240
```

That's it. The script auto-detects your wired/Wi-Fi NIC, reads its real DHCP IP and subnet, and picks a safe `BaseIP` inside that subnet for the synthetic addresses. `-DurationMinutes 240` gives MDE Discovery 4 hours to ingest the announcements. Default is 60 minutes if you omit it.

Common variations:

```powershell
# Preview without doing anything
.\New-SyntheticDiscoveredDevices.ps1 -DryRun

# Smaller or larger device count (default is 10, max in built-in catalog is 35)
.\New-SyntheticDiscoveredDevices.ps1 -DeviceCount 35

# Longer run window
.\New-SyntheticDiscoveredDevices.ps1 -DurationMinutes 240

# Pick a specific NIC if auto-detection picks the wrong one
.\New-SyntheticDiscoveredDevices.ps1 -NicAlias "Ethernet 2"

# Override BaseIP if you want a specific range INSIDE your real subnet
.\New-SyntheticDiscoveredDevices.ps1 -BaseIP 10.0.0.50

# Use a custom profile catalog instead of the built-in 35 profiles
.\New-SyntheticDiscoveredDevices.ps1 -ConfigPath .\my-profiles.json

# ADVANCED: force real IP aliases on the NIC (legacy mode). Only use on lab
# hardware where you have verified that adding secondary IPv4 addresses does
# NOT cause Windows to drop the DHCP IP. On many Surface, Marvell Wi-Fi, and
# managed-endpoint installs this WILL kick the host off the network. The
# script's snapshot/restore safety net will recover, but you'll see no devices.
.\New-SyntheticDiscoveredDevices.ps1 -AddIPAliases

# Cleanup if a prior -AddIPAliases run exited abnormally
.\New-SyntheticDiscoveredDevices.ps1 -Cleanup

# Recovery: re-enable DHCP if a prior -AddIPAliases run left the NIC static
.\New-SyntheticDiscoveredDevices.ps1 -RestoreDhcp -NicAlias "Ethernet 2"
```

### Built-in safety guarantees

* **Default virtual-only mode does not touch the NIC.** No netsh, no New-NetIPAddress, no firewall rule deletion that could orphan addresses.
* If you opt into `-AddIPAliases`, the script snapshots the NIC's full IPv4 state to a local JSON file before any change, and restores it on any error, Ctrl+C, or normal exit.
* Refuses to run if `BaseIP` is outside the host's actual subnet.
* Refuses to run if the host has an APIPA address (`169.254.x.x`).
* Skips the host's own DHCP IP during synthetic IP allocation.
* In `-AddIPAliases` mode: health-checks the host's gateway after every alias and aborts on connectivity loss.
* `-DryRun` prints the full plan without touching anything.

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

## Verifying the announcements actually leave the host

Before blaming MDE Discovery for "no synthetic devices yet", confirm the script is really putting packets on the wire from the expected source IP. The most reliable check is `pktmon`.

```powershell
$out = "$env:USERPROFILE\Downloads\synth.etl"
$txt = "$env:USERPROFILE\Downloads\synth.txt"
& "$env:WinDir\System32\pktmon.exe" stop 2>$null
& "$env:WinDir\System32\pktmon.exe" filter remove
& "$env:WinDir\System32\pktmon.exe" filter add -p 5353 -t UDP
& "$env:WinDir\System32\pktmon.exe" filter add -p 1900 -t UDP
& "$env:WinDir\System32\pktmon.exe" start --capture --comp all --pkt-size 0 --file-name $out
Start-Sleep 60
& "$env:WinDir\System32\pktmon.exe" stop
& "$env:WinDir\System32\pktmon.exe" format $out -o $txt

# Group by source IP -> destination
Get-Content $txt | Select-String '\.5353|\.1900' |
    ForEach-Object {
        if ($_ -match '(\d+\.\d+\.\d+\.\d+)\.\d+\s*>\s*(\d+\.\d+\.\d+\.\d+)\.(5353|1900)') {
            "$($Matches[1])  ->  $($Matches[2]):$($Matches[3])"
        }
    } | Group-Object | Sort-Object Count -Descending | Format-Table Count, Name -Auto
```

**Important:** use `--comp all`, not `--comp nics`. Multicast packets (`224.0.0.251`, `239.255.255.250`) are intercepted at the WFP / virtual switch layer and frequently do not show up in the post-NDIS NIC view. `--comp all` includes those layers.

Expected output (with the script running on, say, Ethernet IP `10.x.y.z`):

```
Count Name
----- ----
  130 10.x.y.z  ->  224.0.0.251:5353
  100 10.x.y.z  ->  239.255.255.250:1900
   90 10.x.y.z  ->  10.x.y.255:1900
```

* All three destinations from the **expected source IP** → script is healthy, network is healthy. Wait for MDE ingestion.
* Source IP is **a different interface** than expected (e.g., a Hyper-V `vEthernet` IP, or Wi-Fi when you wanted Ethernet) → revisit Step 0 pre-flight, in particular the interface metric. Stop the script, fix the metric, restart.
* No matches at all → check that the script's PowerShell window is still printing `[tick N]` lines. If it is and pktmon shows nothing, the multicast sockets failed to bind silently — usually fixed by re-running pre-flight Step 0.4 (the script process probably had its NIC pulled).

## Verifying ingestion in Advanced Hunting

`DeviceNetworkEvents` does **not** log multicast or broadcast UDP, so the absence of port 5353 / 1900 traffic from the seeding host in `DeviceNetworkEvents` is **not** evidence the announcements failed. The two reliable observability signals are:

```kql
// Did MDE Discovery surface the synthetic device names?
DeviceInfo
| where Timestamp > ago(2h)
| where DeviceName startswith "LAB-"
| summarize arg_max(Timestamp, *) by DeviceId
| project DeviceName, DeviceType, DeviceSubtype, OnboardingStatus, OSPlatform
| order by DeviceName asc
```

```kql
// Did the synthetic IP range appear anywhere in DeviceNetworkInfo?
// Replace the prefix with whatever subnet your seeding host is on.
DeviceNetworkInfo
| where Timestamp > ago(2h)
| mv-expand ip = parse_json(IPAddresses)
| extend IPAddress = tostring(ip.IPAddress)
| where IPAddress startswith "10.x.y."   // your subnet's third octet
| project Timestamp, DeviceName, IPAddress, NetworkAdapterType
| order by Timestamp desc
```

```kql
// Sanity check: confirm the seeding host is healthy and reporting telemetry
DeviceNetworkEvents
| where Timestamp > ago(1h)
| where DeviceName == "<your-seeding-host>"
| summarize Hits = count() by ActionType, RemotePort
| order by Hits desc
| take 20
```

Allow up to 30–60 minutes after the first `[tick]` for IT-class devices, and up to several hours for IoT / OT classification.

## Troubleshooting (lessons from end-to-end testing)

| Symptom | Cause | Fix |
|---|---|---|
| Script banner says `Using NIC: Ethernet` but pktmon shows traffic from the Wi-Fi IP. | Windows multicast routing followed the interface metric, not the `-NicAlias` parameter. | Lower the Ethernet metric (`Set-NetIPInterface ... -InterfaceMetric 5`), Ctrl+C the script, restart it. |
| Tick counter keeps incrementing but pktmon `--comp nics` shows nothing. | `--comp nics` misses multicast intercepted at WFP / vSwitch. | Re-run pktmon with `--comp all`. |
| Script started on Wi-Fi, then Wi-Fi was disabled to force Ethernet, ticks continue but no packets leave the host. | Sockets were bound to the now-dead Wi-Fi interface. The tick loop counter does not detect this. | Re-enable Wi-Fi (or set Ethernet metric lower), Ctrl+C the script, restart. |
| `pktmon` returns "Cannot open file" when writing into `C:\Temp`. | `C:\Temp` does not exist or the running account lacks write permission. | Use `$env:USERPROFILE\Downloads` or create `C:\Temp` first. |
| `WARNING: Port 8080 was in use. Using 8081 instead.` | Another HTTP listener already owns 8080. | Cosmetic. Discovery does not require the SSDP `LOCATION:` URL to be reachable for first-pass classification. |
| `DeviceNetworkEvents` shows zero traffic for ports 5353 / 1900 / 5355 / 137. | Defender does not log multicast or broadcast UDP in `DeviceNetworkEvents`. | Use `DeviceInfo` and `DeviceNetworkInfo` instead, plus pktmon for proof of transmission. |
| UDP 5353 / 5355 / 1900 / 137 owned by `svchost` or `System` in `Get-NetUDPEndpoint`. | Normal — Windows DNS Client, SSDP Discovery, NetBIOS, and Bonjour Service all bind these. | The script uses `SO_REUSEADDR` to share the multicast group; this is fine. |
| Devices visible briefly then disappear from the workbook 15–30 minutes after the script stops. | Default `DeviceInfo` retention behavior — the row stops aging forward when telemetry stops. | Run with `-DurationMinutes` long enough for the workbook walkthrough you plan to do. |
| `DeviceInfo` rows appear under non-`LAB-` names (random hex strings). | Common when the host runs the seeding script *and* is itself a Discovery sensor with very weak fingerprints from neighboring real devices on the same subnet. Those are the neighbors, not the synthetic profiles. | Filter by `IPAddress` against the synthetic range (`192.168.x.200-209` by default) or by `DeviceName startswith "LAB-"`. |
| First run from a new account fails with `'.\\New-...ps1' is not recognized`. | The repo isn't cloned on this account yet, or the working directory is not the `Testing\` folder. | Either `git clone` the repo, or fetch just the script from your fork's raw URL with `Invoke-WebRequest` to a local path and run it from there. |
| Script aborts with `Adapter '<name>' is virtual. This script is on-prem physical only.` | Pre-flight refuses virtual NICs by default. This bites the witness pattern above, where the host's IP lives on `vEthernet (<switch name>)` after creating an External vSwitch. | Patch a local copy to downgrade the throw to a warning before running. Example: `(Get-Content $tmp) -replace 'throw "Adapter ''$Requested'' is virtual\. This script is on-prem physical only\."', 'Write-Warning "Adapter ''$Requested'' is virtual; proceeding anyway (override)."' \| Set-Content $tmp` — then run the patched copy with `-NicAlias 'vEthernet (<switch name>)'`. Only do this on lab hardware. |
| Zeek / Suricata / NetFlow show 100s of mDNS/SSDP packets per minute from the seeding host, but `DeviceInfo` never gets a `LAB-*` row even after 60–90 minutes. | Either no onboarded Windows witness on the same L2 (see Step 0.5), **or** the script is running in VIRTUAL-ONLY mode and the witness performs an ARP check that fails because no host actually owns the synthetic IPs. | First confirm a Windows witness exists on the subnet. Then re-run with `-AddIPAliases` so the synthetic IPs are real on the NIC. If `-AddIPAliases` is rejected by the OS, that hardware cannot complete ingestion in this lab and you need to seed from a host where alias creation works (e.g. a generic non-managed Win11 machine on plain Ethernet). |



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
