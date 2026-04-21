# Network Security Operations Center

## Overview
A comprehensive Microsoft Sentinel workbook for full-stack network security monitoring. It unifies **NetFlow**, **Zeek IDS**, **Pi-hole DNS**, **Firewall/Switch syslog**, and **MDE device intelligence** into a single operational dashboard with cross-source correlation, threat hunting, and investigation capabilities.

Built for SOC analysts, network engineers, and security operations teams who need real-time visibility across every layer of the network — from WiFi client sessions to external threat correlation.

## Data Sources
| Source | Table(s) | What It Covers |
|---|---|---|
| NetFlow | `NetFlow_CL` | Bandwidth, flow analytics, top talkers, external connections |
| Zeek IDS | `ZeekLogs_CL` | DNS, HTTP, SSL/TLS, notices, alerts, protocol analysis |
| Pi-hole DNS | `PiholeDNS_CL` | DNS queries, suspicious domains, tunneling detection |
| Firewall / Switch | `Syslog` (kern) | Firewall blocks, WiFi auth/assoc/deauth, link up/down |
| MDE | `DeviceNetworkInfo`, `DeviceNetworkEvents`, `DeviceLogonEvents`, `DeviceProcessEvents`, `DeviceInfo` | Device identity, WiFi SSID resolution, managed/unmanaged status |
| Zeek DHCP | `ZeekLogs_CL` (dhcp) | MAC-to-IP-to-hostname resolution for unmanaged devices |

## Tab Breakdown

| # | Tab | What It Does |
|---|---|---|
| 1 | **Executive Dashboard** | Real-time KPIs across all sources — total events, firewall blocks, Zeek alerts, unique external IPs, DNS queries. Multi-source event volume timeline, data source distribution, top bandwidth consumers, and recent security events. |
| 2 | **DNS Intelligence** | Pi-hole DNS query analysis with top domains, query type distribution, timeline, suspicious domain detection (DGA / tunneling scoring), top clients, unusual query types, and comprehensive threat-scored domain analysis. |
| 3 | **NetFlow Analytics** | Bandwidth KPIs, direction-and-protocol timeline, top 50 internal bandwidth consumers with MAC addresses, protocol distribution, top destination ports, and top 100 external connections with direction indicators. |
| 4 | **Firewall and LAN** | WiFi/LAN event timeline by source and type, switch link-down/up KPIs, AP authentication and disassociation metrics, MDE-enriched WiFi client session tracker (device name, SSID, IP, vendor, managed status), SSID usage charts, managed vs unmanaged breakdown, MDE WiFi sessions, signal quality scoring, connect/disconnect heatmap, rogue device detection, and executive summary tiles. |
| 5 | **Zeek IDS** | Log type distribution, event volume over time, SOC-enriched DNS queries with category filtering (User Browsing, Ads/Tracking, App Telemetry, CDN, Microsoft/Azure, etc.), HTTP and SSL/TLS activity tables with identity enrichment (DeviceName, MAC, SSID, Vendor, MDE status), and Zeek notices/alerts with bidirectional identity resolution. |
| 6 | **Threat Correlation** | Cross-source threat matching — correlates Zeek notices with firewall blocks, DNS anomalies with NetFlow patterns, and identifies devices appearing across multiple threat signals. |
| 7 | **Threat Hunting** | Proactive hunting queries for beaconing detection, unusual port usage, lateral movement patterns, DNS exfiltration indicators, and long-duration connections. |
| 8 | **Global Threat Map** | Geographic visualization of external IP connections with threat intelligence enrichment. |
| 9 | **Investigation Portal** | Unified search across all data sources — enter an IP, domain, or MAC address and get correlated results from NetFlow, Zeek, DNS, firewall, and MDE in one view. |

## Global Parameters
- **Time Range** — Adjustable from 1 hour to 30 days (custom supported)
- **Search IP Address** — Filter all queries by a specific IP
- **Search Domain/URL** — Filter DNS and HTTP queries by domain
- **Search MAC Address** — Filter device-level queries by MAC

## Deploy to Azure

### Option 1: Deploy to Azure (Commercial)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjobarbar%2FDefender_XDR%2Fmain%2FDashboards%2FNetwork-Security-Operations-Center%2Fazuredeploy.json)

### Option 2: Deploy to Azure Government

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjobarbar%2FDefender_XDR%2Fmain%2FDashboards%2FNetwork-Security-Operations-Center%2Fazuredeploy.json)

### Option 3: Manual Deploy
1. Open Microsoft Sentinel → Workbooks → Add workbook → Advanced Editor
2. Paste the contents of `Network-Security-Operations-Center.workbook`
3. Click Apply, then Save

### Option 4: Azure CLI
```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file azuredeploy.json \
  --parameters workbookSourceId="/subscriptions/<subId>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<wsName>"
```

## Prerequisites
- Microsoft Sentinel workspace with Log Analytics
- Data collection configured for the sources you use:
  - **NetFlow** → Custom table `NetFlow_CL` (via Cribl, Logstash, or custom DCR)
  - **Zeek IDS** → Custom table `ZeekLogs_CL` (bridge-mode capture via Cribl → Sentinel)
  - **Pi-hole DNS** → Custom table `PiholeDNS_CL`
  - **Firewall/Switch** → `Syslog` with facility `kern`
  - **MDE** → Microsoft Defender for Endpoint connected to Sentinel
- The workbook gracefully handles missing tables — tabs with no data will show empty results without errors

## Identity Enrichment
The workbook uses a multi-layer identity resolution strategy:
1. **MDE DeviceNetworkInfo** — Real device name, SSID, IP from onboarded endpoints
2. **MDE DeviceInfo** — Vendor and onboarding status
3. **Zeek DHCP** — Hostname and IP for devices not in MDE
4. **Random MAC detection** — Identifies privacy/randomized MACs via the second nibble check
5. **Static SSID map** — Fallback VAP-to-SSID mapping for UniFi access points

## License
MIT
