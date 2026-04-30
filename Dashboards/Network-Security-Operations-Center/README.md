# Network Security Operations Center

## Intro
This workbook gives the SOC a single operational dashboard that unifies network telemetry and endpoint identity for full-stack monitoring, hunting, and investigation.

It includes:
- KPI tiles for total events, firewall blocks, Zeek alerts, unique external IPs, and DNS volume
- Tabs for Executive Dashboard, DNS Intelligence, NetFlow Analytics, Firewall and LAN, Zeek IDS, Threat Correlation, Threat Hunting, Global Threat Map, and Investigation Portal
- Cross-source correlation between NetFlow, Zeek, Firewall syslog, DNS Sinkhole, and MDE
- Threat Intelligence joins against MDTI and abuse.ch (URLhaus, ThreatFox, Feodo Tracker, MalwareBazaar, SSLBL) IOCs
- Identity enrichment that resolves IPs and MACs back to device name, SSID, vendor, and MDE managed status

## Summary For Sysadmin And Security
This workbook gives network and security teams one place to review every layer of the network from a single Sentinel pane.
- Detect beaconing, lateral movement, DGA, and tunneling against TI and behavioral baselines.
- Identify unmanaged or rogue devices on corporate SSIDs and tie them to a real hostname and vendor.
- Triage firewall blocks, Zeek notices, and DNS anomalies side-by-side without pivoting tools.
- Run a single IP, domain, or MAC search across NetFlow, Zeek, DNS, firewall, and MDE for one-stop investigation.

### Tab Breakdown
| # | Tab | Sysadmin And Security Use |
|---|---|---|
| 1 | Executive Dashboard | Real-time KPIs across all sources, multi-source event volume timeline, data source distribution, top bandwidth consumers, and recent security events. |
| 2 | DNS Intelligence | DNS Sinkhole query analysis with top domains, query type distribution, suspicious-domain scoring (DGA / tunneling), top clients, and threat-scored domain analysis. |
| 3 | NetFlow Analytics | Bandwidth KPIs, direction-and-protocol timeline, top 50 internal bandwidth consumers with MAC, protocol distribution, top destination ports, and top 100 external connections. |
| 4 | Firewall and LAN | WiFi/LAN event timeline, switch link-down/up KPIs, AP auth/disassoc metrics, MDE-enriched WiFi session tracker, SSID usage charts, managed vs unmanaged breakdown, signal quality scoring, and rogue device detection. |
| 5 | Zeek IDS | Log type distribution, event volume timeline, SOC-categorized DNS queries (Browsing, Ads, Telemetry, CDN, Microsoft/Azure), HTTP and SSL/TLS tables with identity enrichment, and Zeek notices/alerts with bidirectional identity resolution. |
| 6 | Threat Correlation | Cross-source TI correlation tiles for IP, Domain, URL, and File Hash hits; matches MDTI and abuse.ch IOCs against NetFlow, Zeek, Firewall, DNS, and MDE; flags non-MDE devices touching TI; surfaces top threatened client and top threat country. |
| 7 | Threat Hunting | Proactive hunts for beaconing detection, unusual port usage, lateral movement patterns, DNS exfiltration indicators, and long-duration connections. |
| 8 | Global Threat Map | Geographic visualization of external IP connections with TI enrichment. |
| 9 | Investigation Portal | Unified search across all data sources -- enter an IP, domain, or MAC and get correlated results from NetFlow, Zeek, DNS, firewall, and MDE in one view. |

## Workbook Overview Screenshots

### 1. Executive Dashboard
<!-- paste screenshot here -->

### 2. DNS Intelligence
<!-- paste screenshot here -->

### 3. NetFlow Analytics
<!-- paste screenshot here -->

### 4. Firewall and LAN
<!-- paste screenshot here -->

### 5. Zeek IDS
<!-- paste screenshot here -->

### 6. Threat Correlation
<!-- paste screenshot here -->

### 7. Threat Hunting
<!-- paste screenshot here -->

### 8. Global Threat Map
<!-- paste screenshot here -->

### 9. Investigation Portal
<!-- paste screenshot here -->

## Section Details And What Each One Does

### Executive Dashboard
- What it does: aggregates KPI counts across `NetFlow_CL`, `ZeekLogs_CL`, `PiholeDNS_CL`, `Syslog`, and MDE for a top-down operational view, with a stacked event-volume timeline and recent security events table.
- Primary visuals: KPI tile row, multi-source event timeline, data source distribution donut, top bandwidth consumers, recent security events grid.
- Why it matters: gives the SOC and IT teams a quick health check before drilling into per-source tabs.

### DNS Intelligence
- What it does: parses `PiholeDNS_CL` to surface query volume, top domains, query-type distribution, and suspicious-domain scoring for DGA and tunneling.
- Primary visuals: query timeline, top domains chart, query type distribution, threat-scored domain grid.
- Why it matters: DNS is often the first signal of malware C2 or exfiltration; this tab highlights anomalies before they become incidents.

### NetFlow Analytics
- What it does: queries `NetFlow_CL` for bandwidth and flow KPIs and correlates internal flow producers with MAC addresses and external destinations.
- Primary visuals: bandwidth KPI tiles, direction/protocol timeline, top internal consumers grid, protocol distribution, top destination ports, external connections grid.
- Why it matters: surfaces top talkers, suspicious external destinations, and unusual port activity for capacity planning and threat triage.

### Firewall and LAN
- What it does: parses `Syslog` (kern) for firewall blocks, switch link events, and WiFi association/auth events, then enriches WiFi sessions with MDE device identity.
- Primary visuals: WiFi/LAN event timeline, link-down/up KPIs, MDE-enriched WiFi session tracker, SSID usage chart, managed vs unmanaged breakdown, rogue device grid.
- Why it matters: ties firewall and switch events back to a real device and SSID, exposing rogues and policy gaps.

### Zeek IDS
- What it does: parses `ZeekLogs_CL` across DNS, HTTP, SSL, conn, and notices/alerts; categorizes DNS queries; and enriches HTTP/SSL with device identity from MDE and DHCP.
- Primary visuals: log type distribution, event timeline, categorized DNS query grid, HTTP and SSL tables with identity, Zeek notices/alerts grid.
- Why it matters: protocol-level inspection that catches threats firewalls miss, mapped back to a real endpoint.

### Threat Correlation
- What it does: joins `ThreatIntelIndicators` (MDTI plus abuse.ch URLhaus, ThreatFox, Feodo Tracker, MalwareBazaar, SSLBL) and `SecurityAlert` IP entities against NetFlow, Zeek, Firewall, DNS, and MDE; presents IP, Domain, URL, and File Hash match grids and KPI tiles for top feed, top threatened client, and top threat country.
- Primary visuals: KPI tile row (9 tiles), Cross-Source IP Correlation grid, TI IP/Domain/URL/Hash match grids, top threatened internal clients table.
- Why it matters: turns raw TI feeds into actionable matches against your own traffic and surfaces non-MDE devices touching TI infrastructure.

### Threat Hunting
- What it does: runs proactive KQL hunts for beaconing intervals, rare port usage, internal lateral movement, DNS exfiltration shape, and long-duration connections.
- Primary visuals: hunt result grids, time-series anomaly charts.
- Why it matters: covers patterns that signature-based detections miss and gives the hunt team a starting workbench.

### Global Threat Map
- What it does: geo-resolves external IPs from NetFlow and Zeek conn and renders them on a world map with TI enrichment.
- Primary visuals: choropleth/marker world map, top countries by flow count and TI hits.
- Why it matters: highlights traffic to high-risk geographies and TI-flagged regions at a glance.

### Investigation Portal
- What it does: takes an IP, domain, or MAC and runs a fan-out across `NetFlow_CL`, `ZeekLogs_CL`, `PiholeDNS_CL`, `Syslog`, and MDE tables, presenting all hits in one unified set of grids.
- Primary visuals: per-source result grids scoped to the searched entity, with timestamps and identity columns.
- Why it matters: collapses a multi-tool investigation into a single workbook query.

## Identity Enrichment
The workbook uses a multi-layer identity resolution strategy:
1. **MDE DeviceNetworkInfo** -- Real device name, SSID, IP from onboarded endpoints
2. **MDE DeviceInfo** -- Vendor and onboarding status
3. **Zeek DHCP** -- Hostname and IP for devices not in MDE
4. **Random MAC detection** -- Identifies privacy/randomized MACs via the second-nibble check
5. **Static SSID map** -- Fallback VAP-to-SSID mapping for UniFi access points

## Data Sources
| Source | Table(s) | What It Covers |
|---|---|---|
| NetFlow | `NetFlow_CL` | Bandwidth, flow analytics, top talkers, external connections |
| Zeek IDS | `ZeekLogs_CL` | DNS, HTTP, SSL/TLS, notices, alerts, protocol analysis |
| DNS Sinkhole | `PiholeDNS_CL` | DNS queries, suspicious domains, tunneling detection |
| Firewall / Switch | `Syslog` (kern) | Firewall blocks, WiFi auth/assoc/deauth, link up/down |
| MDE | `DeviceNetworkInfo`, `DeviceNetworkEvents`, `DeviceLogonEvents`, `DeviceProcessEvents`, `DeviceInfo`, `DeviceFileEvents` | Device identity, WiFi SSID resolution, managed/unmanaged status, file hash matches |
| Threat Intel | `ThreatIntelIndicators` | MDTI plus abuse.ch URLhaus, ThreatFox, Feodo Tracker, MalwareBazaar, SSLBL |
| Zeek DHCP | `ZeekLogs_CL` (dhcp) | MAC-to-IP-to-hostname resolution for unmanaged devices |

## Global Parameters
- **Time Range** -- Adjustable from 1 hour to 30 days (custom supported)
- **Search IP Address** -- Filter all queries by a specific IP
- **Search Domain/URL** -- Filter DNS and HTTP queries by domain
- **Search MAC Address** -- Filter device-level queries by MAC

## Prerequisites
- Microsoft Sentinel workspace with Log Analytics
- Data collection configured for the sources you use:
  - **NetFlow** -> Custom table `NetFlow_CL` (via Cribl, Logstash, or custom DCR)
  - **Zeek IDS** -> Custom table `ZeekLogs_CL` (bridge-mode capture via Cribl -> Sentinel)
  - **DNS Sinkhole** -> Custom table `PiholeDNS_CL`
  - **Firewall/Switch** -> `Syslog` with facility `kern`
  - **MDE** -> Microsoft Defender for Endpoint connected to Sentinel
  - **Threat Intel** -> MDTI and/or the abuse.ch ingestion job populating `ThreatIntelIndicators`
- The workbook gracefully handles missing tables -- tabs with no data will show empty results without errors

## The Structure
This folder contains:
- `Network-Security-Operations-Center.workbook`: workbook JSON payload for manual import via Advanced Editor
- `azuredeploy.json`: one-click ARM deployment template

## How To Deploy
Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjobarbar%2FDefender_XDR%2Fmain%2FDashboards%2FNetwork-Security-Operations-Center%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjobarbar%2FDefender_XDR%2Fmain%2FDashboards%2FNetwork-Security-Operations-Center%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- `workspaceName`: your Log Analytics workspace name (default: `SOC-Central`)
- `workbookDisplayName`: display name shown in Azure Monitor / Sentinel (default: `Network Security Operations Center`)
- `workbookId`: leave the default generated value, or provide your own GUID to update an existing instance

### Deployment Note
Azure workbook resources require the underlying resource name to be a GUID. The friendly workbook title comes from `workbookDisplayName`.

## Manual Import (Portal)
1. Go to Microsoft Sentinel or Azure Monitor in your target workspace.
2. Select **Workbooks**, then **New** (or **Add workbook**).
3. Open **Advanced Editor** (the `</>` icon).
4. Paste the contents of `Network-Security-Operations-Center.workbook`.
5. Apply and Save.

## Azure CLI
```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file azuredeploy.json \
  --parameters workbookSourceId="/subscriptions/<subId>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<wsName>"
```

## Notes
- TI matching uses a 30-day TI window joined against 24-hour traffic, so KPI tiles reflect activity in the last 24 hours against any active indicator from the last 30 days.
- The abuse.ch ingestion runs hourly via an Azure Container App Job and writes to `ThreatIntelIndicators` alongside MDTI.
- If a tab shows no data, confirm the underlying custom table exists and is receiving data; the workbook does not error on missing tables, it just returns empty grids.

## License
MIT
