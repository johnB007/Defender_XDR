# DC SYSVOL & AD Replication Health Monitor
## Microsoft Sentinel / Azure Monitor Workbook

**File:** `SYSVOL-DC-Replication-Monitor.workbook`  
**Deploy template:** `azuredeploy.json`

---

## Purpose
This workbook provides full operational visibility into SYSVOL replication health across all Domain Controllers. It consumes events from three DCR XPath-collected Windows Event Log sources:

| Event Log | XPath | Coverage |
|---|---|---|
| `DFS Replication` | `DFS Replication!*` | DFSR-based SYSVOL replication (Server 2008 R2+) |
| `File Replication Service` | `File Replication Service!*` | NTFRS-based SYSVOL replication (legacy) |
| `Directory Service` | `Directory Service!*` | Active Directory DB, KCC, and AD replication |

---

## Tabs

| Tab | Description |
|---|---|
| **📊 Overview** | Summary KPI tiles, volume timeline (areachart), events by source (pie), severity bar chart, error distribution by hour, all-DC event summary table |
| **🔄 DFS Replication** | DFSR KPIs, hourly timeline, event ID bar chart, top DCs by critical events, event ID reference table (with remediation notes), service start/stop/halt timeline, error detail table |
| **📁 File Replication (NTFRS)** | NTFRS KPIs, hourly timeline, event ID bar chart, journal wrap errors by DC, SYSVOL failure events by DC, partner connectivity timeline, event ID reference table (with remediation notes), error detail table |
| **🏢 Directory Service** | DS KPIs, hourly timeline, AD replication event ID bar chart, DNS failure analysis (2087/2088), replication failure detail by DC, event ID reference table (with remediation notes), error detail table |
| **🚨 Critical Events** | Cross-source critical timeline, error distribution by DC + source, multi-source impact table, top 25 critical event IDs, stacked bar chart top-25 DCs, all errors full detail |
| **🖥️ DC Health Matrix** | Per-DC health scorecard (🔴/🟡/🟢/⚪ per source), stacked error comparison, error rate avg/max/total per hour, silent DC detection, per-DC error timeline |

---

## Critical Event IDs Covered

### DFSR (DFS Replication)
| Event ID | Severity | Meaning |
|---|---|---|
| 2213 | 🔴 Critical | DFSR STOPPED — BurFlags D4/D2 restore required |
| 4012 | 🔴 Critical | Partner exceeded max out-of-sync time |
| 5002 | 🔴 Critical | DFSR service stopped unexpectedly |
| 6016 | 🔴 Critical | Could not synchronize replicated folder |
| 4002 | 🔴 Critical | Failed to initialize replication |
| 4004 | 🟡 Warning | Out of disk space on staging volume |
| 2104 | 🟡 Warning | Error replicating a specific file |
| 5008 | 🟡 Warning | Staging area full — file not replicated |
| 2212 | 🟡 Warning | Multiple DFSR instances detected |
| 1206 | 🟡 Warning | Volume dirty flag set |
| 2214 | 🟢 Info | Recovered from unexpected shutdown |
| 5004 | 🟢 Info | DFSR service started |
| 6018 | 🟢 Info | Sync recovered after error |

### NTFRS (File Replication Service)
| Event ID | Severity | Meaning |
|---|---|---|
| 13508 | 🔴 Critical | Trouble replicating from partner |
| 13520 | 🔴 Critical | JRNL_WRAP_ERROR — D2 BurFlags required |
| 13522 | 🔴 Critical | FRS not responding (timeout) |
| 13548 | 🔴 Critical | FRS cannot be contacted |
| 13552 | 🔴 Critical | SYSVOL replication failing |
| 13555 | 🔴 Critical | Serious FRS service problems |
| 13572 | 🔴 Critical | DC SYSVOL NOT READY |
| 13568 | 🟡 Warning | Auto D2 BurFlags applied (journal wrap) |
| 13536 | 🟡 Warning | Cannot resolve partner DNS name |
| 13509 | 🟢 Info | Replication enabled with partner |
| 13553 | 🟢 Info | Connection established with partner |
| 13573 | 🟢 Info | SYSVOL ready / sharing started |

### Directory Service
| Event ID | Severity | Meaning |
|---|---|---|
| 1311 | 🔴 Critical | KCC replication errors detected |
| 1388 | 🔴 Critical | Inbound replication disabled |
| 1925 | 🔴 Critical | Replication link establishment failed |
| 2042 | 🔴 Critical | Too long since last replication — DC isolated |
| 1866 | 🔴 Critical | KCC cannot build spanning tree |
| 1645 | 🔴 Critical | No RID pools available |
| 1173 | 🔴 Critical | Internal AD transaction error |
| 1168 | 🔴 Critical | Unexpected internal exception |
| 5805 | 🔴 Critical | Session setup failed |
| 2087 | 🟡 Warning | DNS failure caused replication failure |
| 1864 | 🟡 Warning | Replication warning threshold reached |
| 2088 | 🟡 Warning | DNS failure (replication succeeded via IP) |
| 1655 | 🟡 Warning | Global catalog contact failed |

---

## Import Into Sentinel

### Option 1 — Import via Azure Portal (recommended)
1. Open **Microsoft Sentinel** → **Workbooks** → **+ Add workbook**
2. Click **Edit** → open the advanced editor (`</>`)
3. Paste the contents of `SYSVOL-DC-Replication-Monitor.workbook`
4. Click **Apply** → **Save**
5. Set the title: `DC SYSVOL & AD Replication Health Monitor`
6. Select your **Log Analytics Workspace** as the data source

### Option 2 — ARM Template Deploy
```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file azuredeploy.json \
  --parameters workbookSourceId="/subscriptions/<subId>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<wsName>"
```

---

## Requirements
- DCR with XPaths: `DFS Replication!*`, `File Replication Service!*`, `Directory Service!*`
- Events must be flowing into the `Event` table in your Log Analytics Workspace (confirm with the screenshot query shown in the Overview of this workbook)
- Workbook works with both **Azure Monitor** and **Microsoft Sentinel** Workbooks gallery
