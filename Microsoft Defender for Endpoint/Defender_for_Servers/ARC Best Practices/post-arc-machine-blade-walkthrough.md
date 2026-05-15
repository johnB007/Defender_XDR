# Azure Arc — Per-Machine Blade Walkthrough

Scope: a single Arc-enabled server after `azcmagent connect` has finished. This walks **every** item in the per-machine left-nav under **portal.azure.com → Azure Arc → Machines → \<server\>** in the exact order Azure shows them, with the same structure on every blade:

- **Portal view** — what you see when you click this item, so you can confirm you're on the right blade.
- **Purpose** — what this blade is for, one line.
- **Verify** — concrete pass/fail signals to check after onboarding.
- **Troubleshoot** — symptom → log path / command / fix.
- **Skip if** — when it does not apply.

Section titles match the portal label **verbatim** (the group name is the H1 above). Click any item in the TOC to jump straight to its section.

The service-level Arc blade (Overview / Infrastructure / Licenses / Migration / Help at the **service** scope) and everything outside Arc (Defender for Cloud, Sentinel, AMA, Update Manager, KQL pack) live in the companion file [`post-arc-onboarding-checklist.md`](./post-arc-onboarding-checklist.md).

---

## Contents — mirrors the portal left-nav

**(Top of left-nav, no group)**
- [Overview](#overview)
- [Activity log](#activity-log)
- [Access control (IAM)](#access-control-iam)
- [Tags](#tags)
- [Diagnose and solve problems](#diagnose-and-solve-problems)
- [Monitor](#monitor)
- [Resource visualizer](#resource-visualizer)

**Settings**
- [Connect](#connect)
- [Security](#security)
- [Extensions](#extensions)
- [Properties](#properties)
- [Locks](#locks)

**Operations**
- [Policies](#policies)
- [Machine Configuration](#machine-configuration)
- [Run command (preview)](#run-command-preview)
- [SQL Server Configuration](#sql-server-configuration)
- [Updates](#updates)
- [Inventory](#inventory)
- [Change tracking](#change-tracking)

**Licenses**
- [Windows Server](#windows-server)

**Windows management**
- [Remote Support (Preview)](#remote-support-preview)
- [Windows Admin Center (preview)](#windows-admin-center-preview)
- [Azure Site Recovery configuration (preview)](#azure-site-recovery-configuration-preview)
- [Best Practices Assessment (preview)](#best-practices-assessment-preview)
- [Azure File Sync (Preview)](#azure-file-sync-preview)

**Monitoring**
- [Insights](#insights)
- [Logs](#logs)
- [Workbooks](#workbooks)

**Automation**
- [CLI / PS](#cli--ps)
- [Tasks](#tasks)

**Help**
- [Resource health](#resource-health)
- [Support + Troubleshooting](#support--troubleshooting)

Also useful:
- [Pre-portal sanity check on the box](#pre-portal-sanity-check-on-the-box)
- [Log paths cheat sheet](#log-paths-cheat-sheet)
- [Extension handler exit codes](#extension-handler-exit-codes)
- [KQL pack for verification & troubleshooting](#kql-pack-for-verification--troubleshooting)
- [One-screen onboarding pass](#one-screen-onboarding-pass)

---

## Pre-portal sanity check on the box

On the machine itself, **before** opening the portal:

```powershell
# Windows
azcmagent show
azcmagent check
```

```bash
# Linux
sudo azcmagent show
sudo azcmagent check
```

Pass criteria: `Agent Status: Connected`, agent version current, every endpoint in `azcmagent check` returns **reachable**. If this is red, no portal blade below will work.

---

## Log paths cheat sheet

| Layer | Windows | Linux |
|---|---|---|
| Agent (himds) | `C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log` | `/var/opt/azcmagent/log/himds.log` |
| Extension manager | `C:\ProgramData\GuestConfig\gc_agent_logs\gcm.log` | `/var/lib/GuestConfig/gc_agent_logs/gc_agent.log` |
| Guest Configuration | `C:\ProgramData\GuestConfig\gc_agent_logs\gc_agent.log` | same as above |
| Per-extension status | `C:\Packages\Plugins\<publisher>.<extension>\<version>\Status\*.status` | `/var/lib/waagent/<publisher>.<extension>-<version>/status/` |
| Per-extension stdout/stderr | `C:\Packages\Plugins\<publisher>.<extension>\<version>\Logs\` | `…/CommandExecution.log`, `…/enable.log` |
| Full bundle (for support) | `azcmagent logs --full --output C:\Temp\arc-logs.zip` | `sudo azcmagent logs --full --output /tmp/arc-logs.tar.gz` |

**Rule of thumb:** `himds.log` for the agent itself · `gcm.log` for "did the extension get told to install at all" · per-extension `enable.log` / `CommandExecution.log` for "why did the install fail."

---

## Extension handler exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Generic failure |
| 9 | Guest Configuration endpoint unreachable (proxy/firewall) |
| 51 | Not supported on this OS / SKU |
| 52 | Missing dependency on the box (typically a runtime or service) |
| 53 | Configuration error in the extension settings JSON |

---

# Top of the left-nav (no group header)

## Overview

- **Portal view:** Summary cards (Status, Last seen, OS, RG, Subscription, Region, Agent version), recent Activity tile, Quick links.
- **Purpose:** Top-level health summary for this Arc machine.
- **Verify:**
  - Status = **Connected**.
  - Last seen within the last 5 minutes.
  - OS name and version detected correctly.
  - Agent version matches current release ([release notes](https://learn.microsoft.com/azure/azure-arc/servers/agent-release-notes)).
  - Subscription + Resource group are the ones you intended.
- **Troubleshoot:**
  - *Disconnected* → on the box: `Get-Service himds` (Win) or `systemctl status himds` (Linux), then `azcmagent check`, then open `himds.log`.
  - *Expired* → onboarding token expired; reconnect with `azcmagent connect …`.
  - Old agent version → upgrade via MSI / `apt` / `yum`. No re-onboarding needed.
- **Skip if:** Never.

## Activity log

- **Portal view:** Time-ordered list of ARM operations on this resource, filterable by event severity, status, timespan, and operation name.
- **Purpose:** Audit trail for everything that has changed on this Arc resource (onboarding, extension installs, license toggles, RBAC changes, tag edits, deletes).
- **Verify:**
  - Filter to last 24h. The onboarding shows as `Microsoft.HybridCompute/machines/write` = Succeeded.
  - Any auto-deploy extension writes (`…/extensions/write`) are Succeeded.
- **Troubleshoot:**
  - Click a failed entry → **JSON** tab → read `properties.statusMessage` and `properties.error`.
  - Capture the **Correlation ID** when opening a support ticket.
  - KQL across all Arc activity in the last 24h: see [AzureActivity extension writes](#kql-pack-for-verification--troubleshooting) below.
- **Skip if:** Never. This is the single source of truth for "who pushed what when."

## Access control (IAM)

- **Portal view:** Role assignments + Deny assignments at the machine scope; *Add → Add role assignment* control.
- **Purpose:** RBAC on this specific Arc machine resource.
- **Verify:**
  - Onboarding identity has *Azure Connected Machine Onboarding* (typically inherited from RG).
  - Operators have *Azure Connected Machine Resource Administrator* or *Contributor*.
  - Read-only users have *Reader* / *Monitoring Reader*.
  - No standing *Owner* assignments at the machine scope.
- **Troubleshoot:**
  - Extension install denied → check IAM at the **RG or subscription** scope as well; extension writes inherit.
  - Defender for Cloud auto-deploy failing → the DFC service principal needs *Azure Connected Machine Resource Administrator* at subscription scope.
- **Skip if:** Never.

## Tags

- **Portal view:** Key/value pairs on the Arc resource.
- **Purpose:** Resource tags (separate from any OS-level metadata) used by downstream policies and schedules.
- **Verify:** Standard set applied **before** wiring anything else:
  - `environment` (prod / test / dev)
  - `owner`
  - `costcenter`
  - `criticality`
  - `patchgroup` (Azure Update Manager targets by this)
  - `dcrAssociation` (which DCR policy attaches)
- **Troubleshoot:**
  - Update Manager schedule never includes this box → wrong / missing `patchgroup` tag.
  - AMA never gets a DCR → DCR policy is keyed on a tag the machine doesn't have.
- **Skip if:** Never.

## Diagnose and solve problems

- **Portal view:** Tile-based self-help — *Connectivity issues*, *Extension issues*, *Agent service issues*, *Onboarding issues*, with run-now buttons and decoded results.
- **Purpose:** Built-in Arc diagnostics. In-portal equivalent of `azcmagent check`, plus error-code translators.
- **Verify:** Run **Connectivity issues** and **Extension issues** once after onboarding — both return green.
- **Troubleshoot:**
  - This blade translates cryptic exit codes (e.g., handler `9`) into plain English.
  - If the blade itself fails to load, the agent is offline — go back to **Overview** and fix Connected status first.
- **Skip if:** Never (always run once after onboarding).

## Monitor

- **Portal view:** Azure Monitor entry point scoped to this resource — Alerts pane, Metrics pane, **Insights** tab.
- **Purpose:** Quick jump into Monitor for this single machine.
- **Verify:**
  - **Insights** tab: *Insights enabled* (after AMA + a VM Insights DCR are in place).
  - No active Critical / Error alerts targeting this resource.
- **Troubleshoot:**
  - *Insights not enabled* even though AMA is Succeeded → no VM Insights DCR is associated. Fix at **Azure Monitor → Data Collection Rules → \<DCR\> → Resources**.
- **Skip if:** AMA hasn't been deployed yet (install it first via **Extensions**).

## Resource visualizer

- **Portal view:** Graph rendering of the machine and its child / linked resources (extensions, ESU license, AAMPLS associations).
- **Purpose:** Visual sanity check that everything you expected to attach actually attached.
- **Verify:** Each expected extension is a child node. Lines exist for ESU license / private link associations if you configured them.
- **Troubleshoot:** A missing node = the extension never deployed at all (different from "deployed but failed" — those still show up as nodes with an error indicator).
- **Skip if:** Never (it's a 30-second visual check).

---

# Settings

## Connect

- **Portal view:** *Connection method* (Public endpoint / Private link), *Proxy server*, *SSH* tile, *Reconnect* command snippet.
- **Purpose:** Network connectivity mode for this machine.
- **Verify:**
  - Connection method matches your design (Public for normal, Private link for restricted networks).
  - For Gov / IL5 confirm endpoints are `*.his.arc.azure.us` / `*.guestconfiguration.azure.us` — not `.com`. (See sibling page [`MDE_ARC_Connectivity_Verify.md`](../MDE_ARC_Connectivity_Verify.md).)
  - Proxy set? Run `azcmagent config list` on the box.
- **Troubleshoot:**
  - Switched to Private link but agent still hits public endpoints. Fix on the box:
    ```powershell
    azcmagent config set connection.type private
    Restart-Service himds, gcarcservice, ExtensionService   # Linux: himdsd, gcad, extd
    ```
  - Proxy URL set but agent still fails → check `proxy.bypass`; Arc should bypass `ArcData,Guestconfig` so it stays inside the proxy for everything else.
- **Skip if:** Never.

## Security

- **Portal view:** *System-assigned managed identity* card (toggle + **Object (principal) ID**), plus a Defender-for-Cloud-driven security posture panel when DFC Plan 2 is enabled.
- **Purpose:** The machine's system-assigned managed identity, and (if DFC P2 is on) its Defender posture summary.
- **Verify:**
  - **Object (principal) ID** is present and non-empty.
  - Defender status (if shown) = Healthy with no High recommendations outstanding.
- **Troubleshoot:**
  - No Object ID → MSI never provisioned; re-run `azcmagent connect` to refresh.
  - Scripts on the box can't get a token → they must use Arc's IMDS-equivalent endpoint (different from Azure VMs):
    - `http://localhost:40342/metadata/identity/oauth2/token?api-version=2020-06-01&resource=https://management.azure.com/`
    - First call returns 401 with a `Www-Authenticate` header pointing to a one-time challenge file. The script reads that file and re-calls with the challenge token. This is Arc's "identity challenge" flow — documented [here](https://learn.microsoft.com/azure/azure-arc/servers/managed-identity-authentication).
- **Skip if:** Never.

## Extensions

- **Portal view:** Table of installed extensions: *Name*, *Publisher*, *Type*, *Version*, *Auto-upgrade*, **Status**, *Provisioning state*. *+ Add* button installs new extensions.
- **Purpose:** Every Arc VM extension on this machine.
- **Verify:** Each expected extension shows **Provisioning state: Succeeded** and **Status: Information**.

  Expected baseline (Linux equivalents in parentheses):

  | Extension | Required when |
  |---|---|
  | `AzureMonitorWindowsAgent` (`AzureMonitorLinuxAgent`) | Always |
  | `AzurePolicyforWindows` (`ConfigurationforLinux`) | Always — Guest Configuration |
  | `MDE.Windows` (`MDE.Linux`) | If Defender for Cloud auto-deploy pushed it (skip if MDE was onboarded by GPO / Intune / script / built-in Server 2019+) |
  | `ChangeTracking-Windows` (`ChangeTracking-Linux`) | If Change Tracking & Inventory are on |
  | `WindowsAdminCenter` | If you use WAC |
  | `RunCommandHandlerWindows` (`RunCommandHandlerLinux`) | If you want the **Run command** blade |

- **Troubleshoot:**
  - Stuck in **Creating** / **Transitioning** > 1h → extension manager never picked up the work. Open `gcm.log` (Win) / extension manager log (Linux).
  - **Failed** → click the extension → read **Status message** verbatim → open the per-extension log: `C:\Packages\Plugins\<pub>.<ext>\<ver>\Status\*.status` and `…\Logs\*.log` (Win) or `/var/lib/waagent/<pub>.<ext>-<ver>/status/` and `CommandExecution.log` (Linux).
  - Exit codes: see [handler exit codes](#extension-handler-exit-codes).
  - Fleet view via KQL: see [unhealthy extensions across all Arc machines](#kql-pack-for-verification--troubleshooting).
- **Skip if:** Never.

## Properties

- **Portal view:** Read-only metadata table — ARM Resource ID, Location, Kind, Agent version, Azure AD tenant ID, Machine ID (GUID), OS profile, vm.fqdn, public key.
- **Purpose:** Canonical identity / metadata of this Arc resource.
- **Verify:**
  - **Operating system** detected correctly.
  - **Cloud provider** matches reality (`Other` = on-prem, `AWS` / `GCP` = cross-cloud).
  - **vm.fqdn** matches what the OS reports.
  - **Tenant** + **Subscription** are correct.
  - Copy the **Resource ID** for policy targeting and support tickets.
- **Troubleshoot:**
  - Wrong OS detected → installer mismatch; reinstall the correct (Win or Linux) agent.
  - Wrong tenant / subscription → `azcmagent disconnect`, then re-onboard with the right credentials.
- **Skip if:** Never.

## Locks

- **Portal view:** Resource lock table; *+ Add* button creates a `Read-only` or `CanNotDelete` lock at the machine scope.
- **Purpose:** Prevent accidental deletion or modification of the Arc resource.
- **Verify:** Production servers carry a `CanNotDelete` lock so the Arc resource (and the MDE / AMA telemetry pipeline that depends on it) cannot be removed accidentally.
- **Troubleshoot:** Can't decommission a server → check locks here **and** at the parent resource group / subscription.
- **Skip if:** Non-production / lab. Optional in dev/test.

---

# Operations

## Policies

- **Portal view:** Compliance table for assignments that target this resource.
- **Purpose:** Azure Policy compliance results for this specific machine.
- **Verify:** Within ~60 min after onboarding, results populate for initiatives that target Arc (Azure Security Benchmark, Deploy AMA, Deploy MDE, Configure DCR association, Deploy Guest Config, etc.).
- **Troubleshoot:**
  - All policies show *Not registered / Not applicable* → assignment scope doesn't cover this RG, or the policy excludes `Microsoft.HybridCompute/machines`.
  - *Non-compliant* with no remediation task → DeployIfNotExists assignments need a managed identity with Contributor at the scope; create a remediation task from the assignment.
- **Skip if:** Never.

## Machine Configuration

- **Portal view:** Guest Configuration assignments and per-rule compliance.
- **Purpose:** DSC/InSpec content executed inside the OS to audit or enforce state.
- **Verify:** Assigned baselines (`AzureWindowsBaseline`, `AzureLinuxBaseline`, etc.) show **Compliant** / **Non-compliant** within ~30–60 min after the Guest Configuration extension installs.
- **Troubleshoot:**
  - Stays **Pending** → Guest Configuration extension is missing or failed (check **Extensions**); open `gc_agent.log`.
  - **Non-compliant** with no detail → click the assignment to see which rules failed.
- **Skip if:** Never.

## Run command (preview)

- **Portal view:** *+ Run a command* button, history list of past runs with output.
- **Purpose:** Push a short PowerShell (Win) or bash (Linux) script through the `RunCommandHandler*` extension; output returns to the portal.
- **Verify:**
  - Handler extension (`RunCommandHandlerWindows` / `Linux`) shows **Succeeded** on **Extensions**.
  - Run one benign test: `Get-Date` (Win) or `uptime` (Linux). Output returns in <1 min.
- **Troubleshoot:**
  - Command never returns → handler extension missing, or outbound to `*.guestconfiguration.azure.com` (`.us`) blocked.
  - Output truncated → 4 KB cap per run; write to blob and emit a SAS URL for larger output.
- **Skip if:** You don't need ad-hoc remote command execution (it is preview / optional).

## SQL Server Configuration

- **Portal view:** Per-instance configuration table — License type, Best Practices Assessment toggle, Automated backups, Entra authentication. Visible only when SQL Server is detected on the box.
- **Purpose:** Manage Arc-enabled SQL Server features on this machine.
- **Verify:** Each instance shows the right license type (Paid / PAYG / SA / Developer). Best Practices Assessment enabled. Automated backups target an Azure Blob container (if desired).
- **Troubleshoot:**
  - Instance not detected → agent service account lacks rights to read SQL registry keys or connect to the instance.
  - Backups failing → storage account needs the Arc machine's MSI granted `Storage Blob Data Contributor`.
- **Skip if:** No SQL Server installed on the box. (Blade is present but empty.)

## Updates

- **Portal view:** Azure Update Manager pane for this machine — Updates summary, Update assessment, Schedules, History.
- **Purpose:** Patch compliance and orchestration via Azure Update Manager.
- **Verify:**
  - **Periodic assessment** = On (one-time setting).
  - A maintenance configuration is attached, or one-time updates is in use.
  - First compliance assessment completes within a few hours.
- **Troubleshoot:**
  - *No assessment data* → machine isn't licensed for Update Manager; needs **Azure Benefits = Licensed** (under SA) or explicit PAYG.
  - Patches stuck *Pending* → upstream WSUS / repo problem, not an Arc problem; UM only orchestrates.
- **Skip if:** Never (every server needs patch visibility).

## Inventory

- **Portal view:** Tabs for Software, Files, Windows services / Linux daemons, Windows Registry.
- **Purpose:** Installed software / files / services inventory, fed by the ChangeTracking extension and AMA.
- **Verify:** `ChangeTracking-Windows` / `-Linux` extension shows **Succeeded**. Software list populates within 30–60 min.
- **Troubleshoot:**
  - Extension Succeeded but Inventory empty → DCR associated with this machine has no ChangeTracking data source. Edit the DCR, add `Microsoft-ConfigurationData`, save.
  - Linux daemons missing → ChangeTracking content only covers SysV / systemd; non-standard init systems aren't inventoried.
- **Skip if:** Never.

## Change tracking

- **Portal view:** Time-series view of changes — Software / Files / Registry / Windows services / Daemons.
- **Purpose:** "What changed and when" — same data source as Inventory, different angle.
- **Verify:** Within 60 min you can see Windows services flipping state, software installs/uninstalls, registry changes you opted to watch. File and registry tracking is opt-in via the DCR — empty by default.
- **Troubleshoot:** No changes detected → most often nothing changed. If you know something changed, confirm the DCR is associated (**Azure Monitor → DCR → Resources**).
- **Skip if:** Never.

---

# Licenses

## Windows Server

- **Portal view:** License status card (Licensed / Not licensed), *Activate Azure benefits* toggle, License type dropdown.
- **Purpose:** Per-machine Windows Server license attestation — drives Software Assurance benefits, ESU eligibility, and which Azure Benefits unlock.
- **Verify:**
  - License status = **Licensed**.
  - **Activate Azure benefits** checked.
  - License type matches reality: Paid (SA), Subscription, PAYG, Developer, EA.
- **Troubleshoot:**
  - License toggle won't enable → tenant doesn't have the corresponding offer attested. Talk to your EA / licensing admin.
  - ESU patches not flowing → on the **service-level** Arc blade `Licenses → Extended Security Updates - Windows Server` you must link the machine to an ESU license resource. This per-machine blade only shows the result of that link.
- **Skip if:** Linux machine (this blade is Windows-Server-specific).

---

# Windows management

> All five of these are **Windows-only** and most are **preview**. Quality-of-life additions, not requirements. Skip the whole group on Linux boxes.

## Remote Support (Preview)

- **Portal view:** Session-start button + audit history.
- **Purpose:** Time-bounded remote-help session brokered through Arc — Microsoft engineers or an internal helper connect without VPN/jump host.
- **Verify:** Only enable on demand. Sessions are auditable in **Activity log**.
- **Troubleshoot:** Session fails to start → outbound to Hybrid Connectivity Service endpoints blocked (same FQDNs as the **Connect → SSH** flow).
- **Skip if:** Linux machine; no active remote-help need.

## Windows Admin Center (preview)

- **Portal view:** *Connect* button that opens WAC in-browser, tunneled through the Arc agent.
- **Purpose:** Browser-based RDP-less server management — services, registry, files, certificates, networking, Defender configuration.
- **Verify:**
  - `WindowsAdminCenter` extension installed and Succeeded.
  - **Connect** opens within ~30s on first launch.
  - Admin has *Windows Admin Center Administrator Login* RBAC on the Arc resource.
- **Troubleshoot:**
  - *Connection failed* → outbound to `*.waconazure.com` (`.us` in Gov) blocked.
  - *Access denied* → missing RBAC, or local OS account doesn't exist (WAC authenticates against the OS, not just Azure).
- **Skip if:** Linux machine.

## Azure Site Recovery configuration (preview)

- **Portal view:** Replication enablement + target Recovery Services Vault picker.
- **Purpose:** Enable Azure Site Recovery replication of the Arc machine into Azure for disaster recovery.
- **Verify:** Only configure for boxes in scope for DR (bandwidth + cost implications).
- **Troubleshoot:** Initial replication never starts → Recovery Services Vault region mismatch or Mobility extension not installed.
- **Skip if:** Box isn't in your DR plan; Linux machine.

## Best Practices Assessment (preview)

- **Portal view:** Last-run summary + *Run assessment* button + findings table.
- **Purpose:** Run Microsoft's BPA rules against the OS + installed Windows roles, return findings.
- **Verify:** Run the assessment once after onboarding, sort by severity, fix or document each High finding.
- **Troubleshoot:** No results → BPA component not installed, or the run wasn't scheduled. Trigger manually from the blade.
- **Skip if:** Linux machine.

## Azure File Sync (Preview)

- **Portal view:** AFS registration card.
- **Purpose:** Enable Azure File Sync agent registration if the box is acting as a file server.
- **Verify:** Only relevant for file servers. Skip on app / DB / web servers.
- **Troubleshoot:** Registration fails → AFS agent install on-box failed; check `%ProgramFiles%\Azure\StorageSyncAgent` logs.
- **Skip if:** Not a file server; Linux machine.

---

# Monitoring

## Insights

- **Portal view:** Performance + Map tabs with CPU / memory / disk / network charts.
- **Purpose:** VM Insights for this machine — perf counters, processes, dependencies. Powered by AMA + a VM Insights DCR.
- **Verify:**
  - Status = *Enabled*.
  - Charts populate within an hour.
  - Map tab fills within ~30 min when the Dependency Agent / Map extension is installed.
- **Troubleshoot:**
  - *Not enabled* even though AMA Succeeded → no VM Insights DCR associated. Fix: associate a DCR that includes `Microsoft-InsightsMetrics`.
  - Map empty → Dependency Agent missing or process-level visibility disabled in DCR.
- **Skip if:** Never (Map tab is optional).

## Logs

- **Portal view:** Log Analytics query editor, pre-scoped to this resource.
- **Purpose:** Run KQL against the workspace this machine reports to.
- **Verify:** `Heartbeat | where Computer == "<name>" | top 1 by TimeGenerated` returns a row within the last 5 min. Expected tables have data — `Perf`, `Event`, `Syslog` (Linux), `SecurityEvent` (if a security DCR is attached).
- **Troubleshoot:**
  - No `Heartbeat` rows → AMA isn't talking to the workspace. Verify AMA extension state, DCR association, and (if private) DCE reachability.
  - Tables missing entirely → DCR has no data sources for them, or you're querying the wrong workspace.
- **Skip if:** Never.

## Workbooks

- **Portal view:** Workbook gallery scoped to this resource; *+ New* to create your own.
- **Purpose:** Saved interactive reports (perf, security baseline, patch compliance).
- **Verify:** Pin one or two templates (*Performance Analysis*, *Security Baseline*) for at-a-glance views.
- **Troubleshoot:** Workbook empty → underlying tables empty; fix **Logs** first.
- **Skip if:** Never (but Workbooks are optional polish).

---

# Automation

## CLI / PS

- **Portal view:** Generated Azure CLI and Azure PowerShell snippets for this resource (tag, install extension, change license, etc.).
- **Purpose:** Auto-generated scriptable equivalents of the GUI actions on this machine.
- **Verify:** Copy a snippet, parameterize, and loop across machines for fleet operations.
- **Troubleshoot:** Snippet fails → missing module (`Az.ConnectedMachine`) or missing RBAC at the scope.
- **Skip if:** You don't manage from script. (You probably should.)

## Tasks

- **Portal view:** Scheduled / triggered task table (still in preview as of 2026).
- **Purpose:** Lightweight automation against this resource.
- **Verify:** Optional. Most teams orchestrate from Azure Automation, Logic Apps, or GitHub Actions instead.
- **Troubleshoot:** Task fails → check run history; it surfaces the underlying Logic App / runbook error.
- **Skip if:** You already have an orchestrator.

---

# Help

## Resource health

- **Portal view:** Status card — *Available* / *Unavailable* / *Unknown* — plus reason text.
- **Purpose:** Azure-side health signal for this Arc resource.
- **Verify:** *Available*.
- **Troubleshoot:**
  - *Unavailable / Disconnected* → agent service down or network broken; back to step 0.
  - Persistent *Unknown* → agent up, but Hybrid Connectivity Service hasn't logged a recent heartbeat; check outbound to `*.his.arc.azure.com` (`.us`).
- **Skip if:** Never.

## Support + Troubleshooting

- **Portal view:** Tile grid — *Diagnose problems*, *New support request*, *Get help* — with the request pre-scoped to this resource.
- **Purpose:** Self-service support and Microsoft case entry, pre-scoped to this machine.
- **Verify:** Used on demand. When opening a Microsoft support case, attach the full agent log bundle:
  ```powershell
  # Windows
  azcmagent logs --full --output "C:\Temp\arc-logs.zip"
  ```
  ```bash
  # Linux
  sudo azcmagent logs --full --output /tmp/arc-logs.tar.gz
  ```
  The bundle contains `himds.log`, extension manager logs, Guest Configuration logs, and per-extension logs — everything Microsoft will ask for on call one.
- **Troubleshoot:** N/A — this blade *is* the troubleshooting tool.
- **Skip if:** Nothing is broken.

---

## KQL pack for verification & troubleshooting

Run these in **Microsoft Sentinel → Logs**, **Defender XDR → Advanced Hunting**, or **Log Analytics** (workspace that this Arc machine reports to). All queries are validated for the LA / Sentinel `arg()` proxy and handle Windows + Linux.

### Unhealthy extensions across all Arc machines

```kusto
// Extensions that are not fully healthy — provisioning failures OR runtime warnings/errors
// 0 rows = clean fleet.
arg("").resources
| where type == "microsoft.hybridcompute/machines/extensions"
| extend machine     = tolower(tostring(split(id, "/extensions/")[0])),
         state       = tostring(properties.provisioningState),
         statusCode  = tostring(properties.instanceView.status.code),
         statusLevel = tostring(properties.instanceView.status.level),
         statusMsg   = tostring(properties.instanceView.status.message),
         version     = tostring(properties.typeHandlerVersion)
| extend platform = case(
            name has_any ("Windows","MDE.Windows","AzurePolicyforWindows"), "Windows",
            name has_any ("Linux","MDE.Linux","ConfigurationforLinux"),     "Linux",
            "Unknown")
| extend reason = case(
            state in ("Failed","Canceled"),                          strcat("provisioning ", state),
            state in ("Creating","Deleting","Updating","Accepted"),  strcat("stuck in ", state),
            statusLevel in ("Error","Warning"),                      strcat("runtime ", statusLevel),
            "ok")
| where reason != "ok"
| project machine, name, platform, reason, state, statusLevel, statusCode, statusMsg, version
| order by platform asc, machine asc, name asc
```

### Extension health distribution (sanity check)

```kusto
// Healthy result: a single row "Succeeded / Information" matching your total extension count.
arg("").resources
| where type == "microsoft.hybridcompute/machines/extensions"
| extend state       = tostring(properties.provisioningState),
         statusLevel = tostring(properties.instanceView.status.level)
| summarize count() by state, statusLevel
| order by state asc
```

### Missing required extensions per machine (AMA + Guest Config + ChangeTracking)

```kusto
// Single arg() call — the LA/Sentinel arg() proxy does not allow joining across two arg() invocations.
// hasMDEExt = false does NOT mean MDE is missing (could be onboarded via GPO/Intune/script).
// hasDefenderForCloudExt = false is EXPECTED on modern P2 with agentless scanning.
arg("").resources
| where type in~ ("microsoft.hybridcompute/machines","microsoft.hybridcompute/machines/extensions")
| extend machineId = iff(type =~ "microsoft.hybridcompute/machines",
                          tolower(id),
                          tolower(tostring(split(id, "/extensions/")[0])))
| extend isMachine = (type =~ "microsoft.hybridcompute/machines")
| summarize
    machineName = take_anyif(name, isMachine),
    osName      = tolower(take_anyif(tostring(properties.osName), isMachine)),
    extensions  = make_set_if(name, not(isMachine))
    by machineId
| where isnotempty(machineName)
| extend
    hasAMA                 = iff(osName == "windows",
                                 extensions has "AzureMonitorWindowsAgent",
                                 extensions has "AzureMonitorLinuxAgent"),
    hasMDEExt              = iff(osName == "windows",
                                 extensions has "MDE.Windows",
                                 extensions has "MDE.Linux"),
    hasDefenderForCloudExt = iff(osName == "windows",
                                 extensions has "AzureSecurityWindowsAgent",
                                 extensions has "AzureSecurityLinuxAgent"),
    hasChangeTracking      = iff(osName == "windows",
                                 extensions has "ChangeTracking-Windows",
                                 extensions has "ChangeTracking-Linux"),
    hasGuestConfig         = iff(osName == "windows",
                                 extensions has "AzurePolicyforWindows",
                                 extensions has "ConfigurationforLinux")
| where hasAMA == false or hasChangeTracking == false or hasGuestConfig == false
| project machineName, osName, hasAMA, hasMDEExt, hasDefenderForCloudExt, hasChangeTracking, hasGuestConfig, extensions
| order by osName asc, machineName asc
```

### True MDE coverage (cross-check Arc inventory against Defender XDR `DeviceInfo`)

```kusto
// Use this when hasMDEExt=false but MDE is onboarded via GPO/Intune/script/built-in Server 2019+.
// Requires the M365 Defender connector in Sentinel.
let arcMachines =
    arg("").resources
    | where type == "microsoft.hybridcompute/machines"
    | extend osName  = tolower(tostring(properties.osName)),
             arcName = tolower(name)
    | project arcName, osName, arcId = tolower(id);
let mdeDevices =
    DeviceInfo
    | where Timestamp > ago(7d)
    | summarize arg_max(Timestamp, *) by DeviceName
    | extend deviceNameLower = tolower(DeviceName)
    | project deviceNameLower, OnboardingStatus, OSPlatform, DeviceId, MachineGroup,
              mdeLastSeen = Timestamp;
arcMachines
| join kind=leftouter mdeDevices on $left.arcName == $right.deviceNameLower
| extend mdeOnboarded = (OnboardingStatus == "Onboarded")
| project arcName, osName, mdeOnboarded, OnboardingStatus, mdeLastSeen, DeviceId, MachineGroup
| order by mdeOnboarded asc, arcName asc
```

### Arc machine heartbeat (AMA + legacy MMA aware)

```kusto
// AMA's Heartbeat Category is "Azure Monitor Agent" (legacy MMA was "Direct Agent").
// ResourceType == "machines" filters to Arc-enabled servers (microsoft.hybridcompute/machines).
Heartbeat
| where TimeGenerated > ago(1h)
| where Category in ("Azure Monitor Agent","Direct Agent") or ResourceType == "machines"
| summarize lastBeat = max(TimeGenerated) by Computer, Category, ResourceType
| extend ageMinutes = datetime_diff('minute', now(), lastBeat)
| order by lastBeat desc
```

### Recent extension write operations (last 24h)

```kusto
// Split into two extends so platform = case(extName ...) can resolve extName.
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue endswith "/extensions/write"
| extend extName = tostring(split(_ResourceId, "/extensions/")[1])
| extend platform = case(
            extName has_any ("Windows","MDE.Windows","AzurePolicyforWindows"), "Windows",
            extName has_any ("Linux","MDE.Linux","ConfigurationforLinux"),     "Linux",
            "Unknown")
| project TimeGenerated, Resource, extName, platform, ActivityStatusValue, Caller, CorrelationId, Properties
| order by TimeGenerated desc
```

### AMA ingestion sanity (is data actually flowing?)

```kusto
union
    (Perf         | where TimeGenerated > ago(1h) | summarize n = count() by Computer | extend table_ = "Perf"),
    (Event        | where TimeGenerated > ago(1h) | summarize n = count() by Computer | extend table_ = "Event"),
    (Syslog       | where TimeGenerated > ago(1h) | summarize n = count() by Computer | extend table_ = "Syslog"),
    (SecurityEvent| where TimeGenerated > ago(1h) | summarize n = count() by Computer | extend table_ = "SecurityEvent")
| order by Computer asc, table_ asc
```

---

## One-screen onboarding pass

Run top-to-bottom on every new Arc machine. Anything that fails sends you to that section's **Troubleshoot** block:

1. [Pre-portal sanity check on the box](#pre-portal-sanity-check-on-the-box) — `azcmagent show` / `azcmagent check` green.
2. [Overview](#overview) — Connected, last seen current.
3. [Activity log](#activity-log) — onboarding entry Succeeded.
4. [Access control (IAM)](#access-control-iam) — least-privilege roles.
5. [Tags](#tags) — standard set applied.
6. [Diagnose and solve problems](#diagnose-and-solve-problems) — Connectivity issues + Extension issues both green.
7. [Monitor](#monitor) — Insights enabled (after AMA is on).
8. [Resource visualizer](#resource-visualizer) — expected child extensions visible.
9. [Connect](#connect) — correct connectivity mode (Public vs Private link, Gov endpoints if IL5).
10. [Security](#security) — MSI Object ID present.
11. [Extensions](#extensions) — every required extension **Succeeded**.
12. [Properties](#properties) — OS, tenant, subscription, FQDN correct.
13. [Locks](#locks) — `CanNotDelete` on production.
14. [Policies](#policies) — assignments scoped, results populating.
15. [Machine Configuration](#machine-configuration) — baselines reporting Compliant / known-Non-compliant.
16. [Run command (preview)](#run-command-preview) — one test command round-trips.
17. [SQL Server Configuration](#sql-server-configuration) — only if SQL is installed.
18. [Updates](#updates) — periodic assessment on, schedule attached.
19. [Inventory](#inventory) — software list populates.
20. [Change tracking](#change-tracking) — DCR has ChangeTracking data source.
21. [Windows Server](#windows-server) (Licenses) — Licensed, Azure benefits activated.
22. [Remote Support (Preview)](#remote-support-preview) — leave off until needed.
23. [Windows Admin Center (preview)](#windows-admin-center-preview) — extension installed, test connect.
24. [Azure Site Recovery configuration (preview)](#azure-site-recovery-configuration-preview) — only if box is in DR scope.
25. [Best Practices Assessment (preview)](#best-practices-assessment-preview) — run once, review High findings.
26. [Azure File Sync (Preview)](#azure-file-sync-preview) — only on file servers.
27. [Insights](#insights) — enabled with charts.
28. [Logs](#logs) — `Heartbeat` row from this machine in last 5 min.
29. [Workbooks](#workbooks) — pin one or two templates.
30. [CLI / PS](#cli--ps) — copy snippets you'll automate from.
31. [Tasks](#tasks) — optional, skip if you orchestrate elsewhere.
32. [Resource health](#resource-health) — Available.
33. [Support + Troubleshooting](#support--troubleshooting) — know where the log bundle command lives.

When step N is red, the **Troubleshoot** subsection of section N above tells you the exact log path, command, or RBAC fix.
