# Threat Operations Dashboard (No MDE/MDI)

A single pane of glass Microsoft Sentinel workbook that delivers a complete threat-operations picture **without** requiring Microsoft Defender for Endpoint (MDE) or Defender for Identity (MDI) sensors. It is built for tenants that have Sentinel, Entra ID, Microsoft 365, and Microsoft Defender Threat Intelligence (MDTI) but have not yet onboarded the endpoint or identity sensors, and it lights up entirely from data those tenants already collect.

---

## What This Workbook Is Built Around

Most "single pane of glass" dashboards assume the customer has every Defender workload streaming in. This one inverts that assumption. It correlates the signals a Sentinel-only customer already has, native incident and analytics data, Entra ID Identity Protection, UEBA (User and Entity Behavior Analytics), ML anomalies, Microsoft 365 (Office, Email, Graph), Azure control plane, Linux Syslog, and the full MDTI indicator feed, into one executive view across host, identity, network, and cloud.

| Pillar | Source Tables | What It Surfaces |
|---|---|---|
| **Native correlation** | `SecurityIncident`, `SecurityAlert` | Open incidents, high/critical alerts, MITRE ATT&CK tactics, top detections firing. |
| **Identity & UEBA** | `BehaviorAnalytics`, `AADRiskyUsers`, `AADUserRiskEvents`, `SigninLogs` | Investigation-priority leaderboard, Identity Protection risk detections, risky users and sign-ins, risk source IPs and countries. |
| **Host telemetry** | `SecurityEvent` (Windows Security Events via AMA) | Adversary tactics mapped to MITRE ATT&CK, logon success vs failure trend, logon-type breakdown, privileged logons, explicit credential use, Kerberos ticket requests, process-creation and LOLBin execution, security-sensitive events (persistence, privilege escalation, defense evasion), and local group enumeration. |
| **Threat intelligence** | `ThreatIntelIndicators` | Indicator coverage by type, provider, confidence, threat family, and freshness, then correlated against every IP, domain, URL, and file hash the tenant logged. |
| **Cloud & email** | `OfficeActivity`, `AuditLogs`, `AzureActivity`, `EmailEvents`, `EmailUrlInfo`, `EmailAttachmentInfo`, `EmailPostDeliveryEvents`, `UrlClickEvents` | BEC tradecraft, privileged role abuse, app-consent grants, and the full Microsoft Defender for Office 365 mail-threat picture. |
| **Sign-in geography** | `SigninLogs` | World map of sign-in origins weighted by volume and colored by failure intensity, plus per-country and per-user drilldowns. |

The design principle: **every panel is built to populate from data a Sentinel-only tenant already has.** Where a richer Defender workload would add depth (for example MDE host enrichment), an upsell note calls it out, but the panel still lights up from native telemetry.

---

## What It Shows

Use the **Time Range** picker and the six **tabs** to pivot between threat views.

### Tab 1: Threat Overview
Whole-environment posture in one view. Headline tiles blend incidents, high/critical alerts, UEBA risk activities, ML anomalies, TI indicators, and risky users. The MITRE ATT&CK chart fuses analytic-alert tactics with UEBA/ML anomaly tactics so leadership sees adversary behavior, not just log volume. Includes incident trend by severity, alert-severity mix, and the top detections firing.

### Tab 2: Host Based Threats
Windows server and workstation threat activity, built entirely on the `SecurityEvent` table from the **Windows Security Events via AMA** connector (Azure Arc plus Azure Monitor Agent). No MDE, no MDI, no Linux. Every pane is organised around what a threat actor does on a host. Headline tiles cover hosts logging, failed logons (4625), privileged logons (4672), explicit credential use (4648), Kerberos tickets (4769), and process creation (4688). The **Adversary Tactics** chart maps raw Windows Event IDs to MITRE ATT&CK tactics (Credential Access, Lateral Movement, Privilege Escalation, Persistence, Defense Evasion, Execution, Discovery). Drilldowns include the logon success vs failure trend (brute force and spray signal), logon-type distribution (Network and RDP lateral-movement surface), top hosts and accounts by privileged logon, explicit credential use (RunAs / pass-the-hash), Kerberos service-ticket requests (Kerberoasting hunt), process-creation inventory, LOLBin and dual-use tool execution, the Security Sensitive Events grid (account creation, group changes, audit-log clearing, scheduled tasks, service installs), and local group membership enumeration (discovery / recon).

### Tab 3: Identity & UEBA
Identity as the perimeter. Leads with Sentinel UEBA InvestigationPriority scoring, fused with Entra ID Identity Protection risk and sign-in telemetry. Includes the UEBA leaderboard, anomalous activity types, Identity Protection risk detections over time, top sign-in failure reasons, the risky-user population by level, new risky users per day, risk-detection types, a live risk-detections feed, risk by country, top risk source IPs, and a risky sign-ins grid.

### Tab 4: Network & Threat Intel
MDTI and network telemetry in one place. Two KPI rows quantify threat-intel coverage and network/API telemetry. A **Threat Intelligence Catalog** profiles the indicator feed by type, provider, confidence, active/revoked status, threat family, and freshness. The **MDTI correlation** grids match live IP indicators against every IP the tenant logged across Entra sign-ins, non-interactive sign-ins, Graph API, the Azure control plane, and Office 365. A **Graph API & Network Telemetry** section exposes call volume, errors, status-class mix, top source IPs, calling applications, user agents, and Syslog volume by facility. A **Sign-in Network Footprint** section shows non-interactive source IPs and per-user IP/country spread. Finally, **M365 indicator matches** correlate malicious domains, URLs, and file hashes against mail and SharePoint/OneDrive/Teams.

> **Reading the MDTI correlation grids:** an empty result is the healthy outcome. It means no currently tracked malicious IP, domain, URL, or hash has touched your environment in the selected window. Any row that appears is a confirmed brush with known-bad infrastructure or tooling and should be triaged immediately. The catalog and telemetry panels around it populate continuously so the tab always shows live data.

### Tab 5: Cloud & SaaS Activity
Threat activity across Microsoft 365, Azure control plane, and Entra ID. Risky mailbox operations and inbox rules (BEC tradecraft), app-consent grants, privileged role adds, conditional-access changes, and failed Azure operations. Includes a dedicated **Email Security (Microsoft Defender for Office 365)** section: threat-signal and mail-flow tiles, threats over time by verdict, verdict mix, top threat sender domains, top URL domains in mail, a full filtered/malicious email detail grid, malicious URLs in mail, attachments and file hashes, post-delivery ZAP remediation, and Safe Links URL clicks.

### Tab 6: Sign-in Geography
Where sign-ins originate worldwide. Bubble size reflects total sign-in volume per country; color intensity (green to red, log-scaled) reflects failed sign-ins, surfacing brute-force, password-spray, and impossible-travel hotspots at a glance. Drilldown grids break out volume, failures, risk, conditional-access blocks, and legacy-auth by country/city, then failed sign-ins by user with geo, apps, client, risk, and CA detail.

---

## How To Use This Workbook

### Leadership and CISO
- **Tab 1 (Threat Overview)** is the executive briefing view: one row of headline counts plus the ATT&CK tactics chart answers "what is happening in our environment right now?" without log-diving.
- Use the **Time Range** picker to move between a 24-hour operational view and a 90-day trend view for board reporting.

### SOC Analysts and Threat Hunters
- **Triage flow**: start in Tab 1 top detections, pivot to Tab 3 for the implicated identity, Tab 2 for the host, and Tab 4 to check whether any involved IP/domain/hash matches threat intelligence.
- **Identity investigations**: Tab 3's UEBA leaderboard and risk-detections feed rank users by anomalous behavior and live Identity Protection risk; the risk-source-IP and risk-by-country grids scope the infrastructure behind it.
- **Threat-intel correlation**: Tab 4's match grids are high-value true-positive detectors. A hit is a confirmed IOC touch; cross-reference the actor and source columns and open an incident.
- **Email triage**: Tab 5's email detail grid colors verdict and delivery action so delivered threats jump out; pivot to the URLs, attachments, ZAP, and Safe Links grids to scope blast radius.
- **Geography**: Tab 6's map and grids surface anomalous sign-in origins and the users failing from them.

### Compliance and Audit
- Every grid supports CSV export for evidence collection.
- Tab 3's risky-user state and Tab 5's privileged-operation grids map to access-review and least-privilege findings.
- Tab 6's per-country sign-in summary supports data-residency and anomalous-access questionnaires.

---

## Prerequisites

- A Sentinel-enabled Log Analytics workspace.
- Connectors providing the tables used above. The workbook degrades gracefully (`isfuzzy=true` unions) when a given table is absent, so partial connector coverage still renders:
  - **Entra ID**: `SigninLogs`, `AADNonInteractiveUserSignInLogs`, `AADServicePrincipalSignInLogs`, `AADRiskyUsers`, `AADUserRiskEvents`, `AuditLogs`.
  - **Microsoft 365**: `OfficeActivity`, `EmailEvents`, `EmailUrlInfo`, `EmailAttachmentInfo`, `EmailPostDeliveryEvents`, `UrlClickEvents`.
  - **Microsoft Graph**: `MicrosoftGraphActivityLogs`.
  - **Azure**: `AzureActivity`.
  - **Host**: `SecurityEvent` via the **Windows Security Events via AMA** connector (Azure Arc + Azure Monitor Agent). `Syslog` is consumed only by the Network tab; the Host tab is `SecurityEvent` only.
  - **Sentinel native**: `SecurityIncident`, `SecurityAlert`, `BehaviorAnalytics` (UEBA), `Anomalies`.
  - **Threat intel**: `ThreatIntelIndicators` (MDTI and/or any TI connector or upload).
- Permissions to deploy ARM templates in the target resource group.

---

## Known Limitations

- **No MDE/MDI sensors required by design.** Host pivots are built on `SecurityEvent` from the **Windows Security Events via AMA** connector rather than `Device*` tables, and identity is built on Entra ID + UEBA rather than `IdentityDirectoryEvents`. Onboarding MDE/MDI adds depth (device timelines, lateral-movement graphs) but is not required for the workbook to function.
- **Host tab depends on Windows audit policy.** Panes such as process creation, LOLBin execution, and the Adversary Tactics chart only fill once the relevant Windows audit subcategories are enabled (for example Audit Process Creation for 4688). Sparse 4688/4625 volume means light Execution and brute-force panels until auditing is broadened across the onboarded estate.
- **MDTI match grids correctly show "no results" when there is no overlap.** The global TI feed tracks tens of millions of indicators; for a healthy tenant, almost none ever touch your logged telemetry. Empty grids are a true negative, not a bug. The surrounding catalog and telemetry panels populate continuously.
- **Microsoft 365 threat verdicts** (`ThreatTypes`, `DetectionMethods`) populate most fully when the workspace receives the unified Defender email tables; the email panels are also built to light up from delivery action, quarantine location, bulk-complaint level, and the always-populated URL/attachment/ZAP/click tables.
- Cloud-service source IPs (for example Microsoft datacenter egress ranges seen in `MicrosoftGraphActivityLogs`) are legitimate and will never match threat intelligence.

---

## Files

- `Threat-Operations-Dashboard-No-MDE-MDI.json`: workbook JSON payload for manual import.
- `azuredeploy.json`: one-click ARM deployment template (Commercial plus Gov).
- `images/`: screenshots referenced in this README.

---

## How To Deploy

Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FWorkbooks%2FThreat-Operations-Dashboard-No-MDE-MDI-Workbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FWorkbooks%2FThreat-Operations-Dashboard-No-MDE-MDI-Workbook%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- `workspaceName`: the Log Analytics workspace name (default: `SOC-Central`).
- `workbookDisplayName` default: `Threat Operations Dashboard No MDE/MDI`.
- `workbookId`: leave the `newGuid()` default to create a new workbook instance.

### Deployment Note
- The workbook is deployed as `kind: shared` and is scoped to the selected Log Analytics workspace.
- To import the workbook manually instead, open Sentinel **Workbooks** > **+ Add workbook**, click the pencil (Edit) icon, then **Advanced Editor**, and paste the contents of `Threat-Operations-Dashboard-No-MDE-MDI.json`.
