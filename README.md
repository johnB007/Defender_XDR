# KQL

This repository contains KQL content for Microsoft Defender XDR and Microsoft Sentinel.

Kusto Query Language is used to search, filter, join, summarize, and investigate security telemetry. It works well for incident response, threat hunting, detection tuning, and reporting because the syntax is readable and maps cleanly to log data.

For documentation, see [Kusto Query Language (KQL) overview](https://learn.microsoft.com/en-us/kusto/query/?view=azure-data-explorer).

## 📌 Pinned Dashboard

### [Network Security Operations Center](Dashboards/Network-Security-Operations-Center/)

A comprehensive Microsoft Sentinel workbook unifying **NetFlow**, **Zeek IDS**, **DNS Sinkhole**, **Firewall/Switch syslog**, and **MDE device intelligence** into a single operational SOC dashboard with cross-source correlation, threat hunting, and investigation capabilities.

**9 tabs:** Executive Dashboard · DNS Intelligence · NetFlow Analytics · Firewall and LAN · Zeek IDS · Threat Correlation · Threat Hunting · Global Threat Map · Investigation Portal

➡️ See [Dashboards/Network-Security-Operations-Center/README.md](Dashboards/Network-Security-Operations-Center/README.md) for deployment and details.
