# Post Azure Arc Onboarding — Per-Machine Blade Walkthrough

Scope: a single Arc-enabled server after `azcmagent connect` has finished. This walks **every** item in the per-machine left-nav under **portal.azure.com → Azure Arc → Machines → \<server\>** in the exact order Azure shows them, one blade per section, with the same four-part structure every time:

- **Purpose** — what this blade is for, in one line.
- **Check** — the pass/fail signals to verify after onboarding.
- **If broken** — symptom → log or fix.
- **Skip if** — when this blade does not apply (preview features, optional roles).

Service-level Arc blades (Overview / Infrastructure / Licenses / Migration / Help at the **service** scope) and everything outside Arc (Defender for Cloud, Sentinel, AMA, Update Manager, KQL) are in the companion file [`post-arc-onboarding-checklist.md`](./post-arc-onboarding-checklist.md).

---

## 0. Before you open the portal

On the box:

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

Must return `Agent Status: Connected` and every endpoint **reachable**. Nothing below works until this is green.

**Log paths (memorize these):**

| OS | Agent | Extension manager | Per-extension |
|---|---|---|---|
| Windows | `C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log` | `…\GuestConfig\gc_agent_logs\gcm.log` | `C:\Packages\Plugins\<pub>.<ext>\<ver>\Status\` and `…\Logs\` |
| Linux | `/var/opt/azcmagent/log/himds.log` | `/var/lib/GuestConfig/gc_agent_logs/gc_agent.log` | `/var/lib/waagent/<pub>.<ext>-<ver>/status/`, `CommandExecution.log` |

---

# Top of the left-nav (above any group header)

## 1. Overview

- **Purpose:** Machine summary — connection status, last heartbeat, OS, agent version, RG, subscription, region.
- **Check:** Status = **Connected**. Last seen within 5 min. OS detected correctly. Agent version current.
- **If broken:** Status = *Disconnected* → on the box `Get-Service himds` / `systemctl status himds`, then `azcmagent check`, then `himds.log`. Status = *Expired* → run `azcmagent connect …` to reconnect.
- **Skip if:** Never.

## 2. Activity log

- **Purpose:** ARM audit trail for everything that has happened to this Arc resource (onboarding, extension installs, license toggles, RBAC changes, deletes).
- **Check:** Last 24h filter — find `Microsoft.HybridCompute/machines/write` (onboarding) and `…/extensions/write` (any auto-deploys). All Succeeded.
- **If broken:** Click any failed entry → **JSON** tab → read `properties.statusMessage` and `properties.error`. Capture the **Correlation ID** for support tickets.
- **Skip if:** Never. This is your single source of truth for "who pushed what extension when."

## 3. Access control (IAM)

- **Purpose:** RBAC at the machine scope.
- **Check:** Onboarding identity has *Azure Connected Machine Onboarding* at RG scope. Admins have *Azure Connected Machine Resource Administrator*. No Owner at machine scope.
- **If broken:** Extension push denied → IAM is usually missing at the **resource-group or subscription** scope, not just the machine. Defender for Cloud auto-deploy failing → DFC service principal needs *Azure Connected Machine Resource Administrator* at the subscription.
- **Skip if:** Never.

## 4. Tags

- **Purpose:** Resource tags on the Arc machine (separate from OS tags).
- **Check:** Standard set applied: `environment`, `owner`, `costcenter`, `criticality`, `patchgroup`, optionally `dcrAssociation`.
- **If broken:** Update Manager schedule never picks the box → wrong or missing `patchgroup` tag. AMA never gets a DCR → DCR association is keyed on a tag the machine doesn't have.
- **Skip if:** Never. Tag **before** wiring anything else, because policies and schedules below target by tag.

## 5. Diagnose and solve problems

- **Purpose:** Built-in Arc diagnostics — in-portal version of `azcmagent check`, with playbooks for the most common failures.
- **Check:** Run **Connectivity issues** and **Extension issues** once after onboarding. Both should return green.
- **If broken:** This blade translates cryptic exit codes into plain English (e.g., handler code `9` → "Guest Configuration endpoint unreachable"). If the blade itself fails to load, the agent is offline — fix the **Overview** Connected status first.
- **Skip if:** Never. Always run once after onboarding to catch invisible network gaps.

## 6. Monitor

- **Purpose:** Azure Monitor shortcut scoped to this machine — alerts, metrics, Insights enablement.
- **Check:** **Insights** tab says *Insights enabled* once AMA + VM Insights DCR are in place. No active Critical/Error alerts.
- **If broken:** *Insights not enabled* even though AMA is Succeeded → no VM Insights DCR is associated. Fix at **Azure Monitor → Data Collection Rules → \<DCR\> → Resources**.
- **Skip if:** AMA isn't deployed yet (do that first via **Settings → Extensions**).

## 7. Resource visualizer

- **Purpose:** Graph of the Arc machine and its child resources (extensions, license link, private link associations).
- **Check:** Every expected extension appears as a child node. ESU license / AAMPLS associations show as connecting edges.
- **If broken:** A missing node means the extension never deployed at all (different from "deployed but failed" — that one still shows up).
- **Skip if:** Never, but it's quick — 30-second visual sanity check.

---

# Settings group

## 8. Settings → Connect

- **Purpose:** Connectivity mode (Public endpoint vs Private link), proxy settings, reconnect command.
- **Check:** Connectivity method matches your design. For Gov/IL5 confirm endpoints are `*.his.arc.azure.us` / `*.guestconfiguration.azure.us` — not `.com`. Proxy set? Run `azcmagent config list` on the box.
- **If broken:** Switched to Private link but agent still hits public endpoints → on the box `azcmagent config set connection.type private`, then restart `himds, gcarcservice, ExtensionService` (Win) / `himdsd, gcad, extd` (Linux).
- **Skip if:** Never.

## 9. Settings → Security

- **Purpose:** The machine's system-assigned managed identity (Object ID), plus Defender for Cloud status if Plan 2 is enabled.
- **Check:** **System-assigned managed identity → Object (principal) ID** is present and non-empty. Defender status (if shown) = Healthy.
- **If broken:** No Object ID → MSI never provisioned; re-run `azcmagent connect`. Scripts on the box can't get a token → they must call the Arc-specific endpoint `http://localhost:40342/metadata/identity/oauth2/token` (port 40342, **not** the Azure VM IMDS 169.254.169.254), and handle Arc's one-time challenge file flow.
- **Skip if:** Never.

## 10. Settings → Extensions

- **Purpose:** Lists every Arc VM extension on this machine; install/upgrade/uninstall happens here.
- **Check:** Each expected extension shows **Provisioning state: Succeeded**:

  | Extension (Win → Linux) | Required when |
  |---|---|
  | AzureMonitorWindowsAgent → AzureMonitorLinuxAgent | Always |
  | AzurePolicyforWindows → ConfigurationforLinux | Always (Guest Configuration) |
  | MDE.Windows → MDE.Linux | Defender for Servers P2 auto-deploy (optional if MDE already onboarded via GPO/Intune/script) |
  | ChangeTracking-Windows → ChangeTracking-Linux | Change Tracking & Inventory |
  | WindowsAdminCenter | Optional, for WAC |
  | RunCommandHandlerWindows → RunCommandHandlerLinux | If you want **Operations → Run command** |

- **If broken:** Stuck in **Creating** / **Transitioning** > 1h → extension manager never picked it up; open `gcm.log`. Shows **Failed** → click extension → read **Status message** → open per-extension log under `C:\Packages\Plugins\…\Status\` or `/var/lib/waagent/…/status/`. Handler exit codes: `0` ok, `1` generic, `9` GC endpoint unreachable, `51` not supported, `52` missing dep, `53` config error.
- **Skip if:** Never.

## 11. Settings → Properties

- **Purpose:** Read-only resource metadata (ARM resource ID, location, agent version, tenant ID, machine ID, OS profile, vm.fqdn, public key).
- **Check:** OS detected correctly. Cloud provider reflects reality (`Other` for on-prem). Correct tenant + subscription. Copy the **Resource ID** — you'll need it for policy targeting and support tickets.
- **If broken:** Wrong OS detected → installer mismatch; reinstall the correct (Win or Linux) agent. Wrong tenant/subscription → `azcmagent disconnect`, then re-onboard with correct credentials.
- **Skip if:** Never.

## 12. Settings → Locks

- **Purpose:** Azure RM resource locks (Read-only, Delete) at the machine scope.
- **Check:** Production servers have a `CanNotDelete` lock so the Arc resource and its MDE/AMA wiring can't be removed accidentally.
- **If broken:** Can't decommission a box → check locks here **and** at the parent resource group.
- **Skip if:** Non-production / lab. Optional in dev/test.

---

# Operations group

## 13. Operations → Policies

- **Purpose:** Azure Policy compliance results for this specific machine.
- **Check:** Within ~60 min after onboarding, results populate for any initiatives that target Arc (Azure Security Benchmark, Deploy AMA, Deploy MDE, Configure DCR, etc.).
- **If broken:** *Not registered / Not applicable* everywhere → assignment scope doesn't cover this RG, or the policy excludes `Microsoft.HybridCompute/machines`. *Non-compliant* with no remediation task → DeployIfNotExists assignments need a managed identity with Contributor at the scope; create a remediation task from the assignment.
- **Skip if:** Never.

## 14. Operations → Machine Configuration

- **Purpose:** Guest Configuration — DSC/InSpec content executed inside the OS to audit or enforce state.
- **Check:** Assigned baselines (`AzureWindowsBaseline`, `AzureLinuxBaseline`, etc.) show **Compliant** / **Non-compliant** within ~30–60 min after the Guest Configuration extension lands.
- **If broken:** Stays **Pending** → Guest Configuration extension missing or failed (see **Settings → Extensions**); open `gc_agent.log`. **Non-compliant** with no detail → click the assignment to see which rules failed.
- **Skip if:** Never.

## 15. Operations → Run command (preview)

- **Purpose:** Push a short PowerShell (Win) or bash (Linux) script through the `RunCommandHandler*` extension; output returns to the portal.
- **Check:** Handler extension shows **Succeeded** in **Settings → Extensions**. Test once: `Get-Date` (Win) / `uptime` (Linux) — output returns in <1 min.
- **If broken:** Command never returns → handler extension not installed, or outbound to `*.guestconfiguration.azure.com` / `.us` blocked. Output truncated → built-in 4 KB cap per run; write to blob and emit a SAS URL for larger output.
- **Skip if:** You don't need ad-hoc remote command execution (preview, optional).

## 16. Operations → SQL Server Configuration

- **Purpose:** Manages Arc-enabled SQL Server features when the agent has discovered a SQL instance on the box.
- **Check:** Each instance shows up with the right license type (Paid / PAYG / SA / Developer). Best Practices Assessment enabled. Automated backups target an Azure Blob container (if you want it).
- **If broken:** Instance not detected → agent service account lacks rights to read SQL registry keys or connect to the instance. Backups failing → storage account needs the Arc machine's MSI granted `Storage Blob Data Contributor`.
- **Skip if:** No SQL Server installed on the box. (Blade is still visible but empty.)

## 17. Operations → Updates

- **Purpose:** This machine's pane in Azure Update Manager — patch compliance, pending updates, scheduled deployments.
- **Check:** **Periodic assessment** = On (one-time setting). A maintenance configuration is attached, or you're using one-time updates. First compliance assessment finishes within a few hours.
- **If broken:** *No assessment data* → machine isn't licensed for Update Manager; needs **Azure Benefits = Licensed** (under SA) or explicit PAYG. Patches stuck *Pending* → upstream WSUS/repo problem, not an Arc problem.
- **Skip if:** Never (every server needs patch visibility).

## 18. Operations → Inventory

- **Purpose:** Installed software / files / Windows services / Linux daemons inventory, fed by ChangeTracking + AMA.
- **Check:** `ChangeTracking-Windows` / `-Linux` extension shows **Succeeded**. Inventory list populates within 30–60 min.
- **If broken:** Extension Succeeded but Inventory empty → DCR associated with this machine has no ChangeTracking data source. Edit the DCR, add `Microsoft-ConfigurationData` (the ChangeTracking data source), save.
- **Skip if:** Never (audit and drift visibility is essential).

## 19. Operations → Change tracking

- **Purpose:** Same data source as Inventory, time-series view: file / registry / software / service start-stop events.
- **Check:** Within 60 min you can see Windows services flipping, software install/uninstall, registry changes you configured to watch. File/registry tracking is opt-in via the DCR — empty by default.
- **If broken:** *No changes detected* → most often nothing actually changed. If you know something changed, confirm the DCR is associated (**Azure Monitor → DCR → Resources**).
- **Skip if:** Never.

---

# Licenses group

## 20. Licenses → Windows Server

- **Purpose:** Per-machine Windows Server license attestation — determines Software Assurance benefits, ESU eligibility, and which Azure Benefits unlock.
- **Check:** License status = **Licensed**. *Activate Azure benefits* checked. License type matches reality (Paid / Subscription / PAYG / Developer / EA).
- **If broken:** License toggle won't enable → tenant doesn't have the corresponding offer attested; talk to your EA/licensing admin. ESU patches not flowing → on the **service-level** Arc blade *Licenses → Extended Security Updates - Windows Server* you must **link** the machine to an ESU license resource; this per-machine blade only shows the result.
- **Skip if:** Linux box (blade is Windows-Server-specific).

---

# Windows management group

> All five of these are **Windows-only** and most are **preview**. They are quality-of-life additions, not requirements. Skip the whole group on Linux boxes.

## 21. Windows management → Remote Support (Preview)

- **Purpose:** Time-bounded remote-help session brokered through Arc — Microsoft engineers or an internal helper connect to the OS without VPN/jump host.
- **Check:** Only enable on demand for a specific session. Sessions are auditable in **Activity log**.
- **If broken:** Session fails to start → outbound to Hybrid Connectivity Service endpoints blocked (same FQDNs as the **Connect → SSH** flow).
- **Skip if:** No active remote-help need; Linux machine.

## 22. Windows management → Windows Admin Center (preview)

- **Purpose:** Browser-based RDP-less server management tunneled through the Arc agent (services, registry, files, certificates, networking, Defender configuration).
- **Check:** Install the `WindowsAdminCenter` extension. Click **Connect** — first launch takes ~30s. Admin needs *Windows Admin Center Administrator Login* RBAC on the Arc resource.
- **If broken:** *Connection failed* → outbound to `*.waconazure.com` (`.us` in Gov) blocked. *Access denied* → missing RBAC, or local OS account doesn't exist (WAC authenticates against the OS, not just Azure).
- **Skip if:** Linux machine.

## 23. Windows management → Azure Site Recovery configuration (preview)

- **Purpose:** Enables Azure Site Recovery replication of the Arc machine into Azure for disaster recovery.
- **Check:** Only configure for boxes in scope for DR (replication has bandwidth + cost implications).
- **If broken:** Initial replication never starts → Recovery Services Vault region mismatch, or Mobility extension not installed.
- **Skip if:** Box isn't in your DR plan; Linux machine.

## 24. Windows management → Best Practices Assessment (preview)

- **Purpose:** Runs Microsoft's BPA rules against the OS + installed Windows roles, returns findings.
- **Check:** Run the assessment once, sort by severity, fix or document each High finding.
- **If broken:** No results → BPA component not installed, or the run wasn't scheduled; trigger manually from the blade.
- **Skip if:** Linux machine.

## 25. Windows management → Azure File Sync (Preview)

- **Purpose:** Enables Azure File Sync agent registration if the box is acting as a file server.
- **Check:** Only relevant for file servers. Skip on app/DB/web servers.
- **If broken:** Registration fails → AFS agent install on-box failed; check `%ProgramFiles%\Azure\StorageSyncAgent` logs.
- **Skip if:** Not a file server; Linux machine.

---

# Monitoring group

## 26. Monitoring → Insights

- **Purpose:** VM Insights view — perf counters, processes, dependencies (Map feature). Powered by AMA + VM Insights DCR.
- **Check:** Status = *Enabled*. CPU/memory/disk/network charts populate within an hour. Map tab fills within ~30 min if the Dependency Agent / Map extension is installed.
- **If broken:** *Not enabled* even though AMA Succeeded → no VM Insights DCR associated. Fix: associate a DCR that includes `Microsoft-InsightsMetrics`. Map empty → Dependency Agent missing or process-level visibility disabled in DCR.
- **Skip if:** Never (but Map is optional).

## 27. Monitoring → Logs

- **Purpose:** Log Analytics workspace query scoped to this machine.
- **Check:** `Heartbeat | where Computer == "<name>" | top 1 by TimeGenerated` returns a row within the last 5 min. Expected tables have data: `Perf`, `Event`, `Syslog` (Linux), `SecurityEvent` (if a security DCR is attached).
- **If broken:** No Heartbeat → AMA isn't talking to the workspace. Verify AMA state, DCR association, and (if private) DCE reachability. Tables missing entirely → DCR has no data sources for them, or you're querying the wrong workspace.
- **Skip if:** Never.

## 28. Monitoring → Workbooks

- **Purpose:** Interactive saved reports scoped to this machine (perf, security baseline, patch compliance).
- **Check:** Pin one or two templates (*Performance Analysis*, *Security Baseline*) for at-a-glance views.
- **If broken:** Workbook empty → underlying tables empty; fix **Logs** first.
- **Skip if:** Never (but Workbooks are optional polish).

---

# Automation group

## 29. Automation → CLI / PS

- **Purpose:** Auto-generated Azure CLI / Azure PowerShell snippets for managing this exact resource (tag, install extension, change license, etc.).
- **Check:** Use it to script repeatable actions — copy the snippet, parameterize, loop across machines.
- **If broken:** Snippet fails when run → missing module (`Az.ConnectedMachine`) or missing RBAC at the scope.
- **Skip if:** You don't manage from script. (You probably should.)

## 30. Automation → Tasks

- **Purpose:** Scheduled / triggered automation against this resource (still preview as of 2026).
- **Check:** Optional. Most teams orchestrate from Azure Automation, Logic Apps, or GitHub Actions instead.
- **If broken:** Task fails → check run history; surface the underlying Logic App / runbook error.
- **Skip if:** You already have an orchestrator (Automation Account / Logic App / GHA).

---

# Help group

## 31. Help → Resource health

- **Purpose:** Azure-side health signal for this Arc resource — Available / Unavailable / Unknown.
- **Check:** *Available*.
- **If broken:** *Unavailable / Disconnected* → agent service down or network broken; back to step 0. Persistent *Unknown* → agent up, but Hybrid Connectivity Service hasn't logged a recent heartbeat; check outbound to `*.his.arc.azure.com` / `.us`.
- **Skip if:** Never.

## 32. Help → Support + Troubleshooting

- **Purpose:** Self-service support — diagnostic log collector, common-problem playbooks, entry point to open a Microsoft case pre-scoped to this resource.
- **Check:** You don't routinely use this — it's the "on demand" tool. When opening a support case, attach the full agent log bundle:
  ```powershell
  # Windows
  azcmagent logs --full --output "C:\Temp\arc-logs.zip"
  ```
  ```bash
  # Linux
  sudo azcmagent logs --full --output /tmp/arc-logs.tar.gz
  ```
  The bundle contains `himds.log`, extension manager logs, Guest Configuration logs, and per-extension logs — everything Microsoft will ask for on call one.
- **If broken:** N/A — this blade is itself the troubleshooting tool.
- **Skip if:** Nothing is broken.

---

# Onboarding pass — one screen, in order

For every newly onboarded Arc machine, do these 32 steps top-to-bottom. Anything that fails sends you to that step's **If broken** block:

1. Overview — Connected, last seen current.
2. Activity log — onboarding entry Succeeded.
3. Access control (IAM) — least-privilege roles.
4. Tags — standard set applied.
5. Diagnose and solve problems — Connectivity issues + Extension issues both green.
6. Monitor — Insights enabled (after AMA is on).
7. Resource visualizer — expected child extensions visible.
8. Settings → Connect — correct connectivity mode for your environment.
9. Settings → Security — MSI Object ID present.
10. Settings → Extensions — every required extension **Succeeded**.
11. Settings → Properties — OS, tenant, subscription, FQDN correct.
12. Settings → Locks — `CanNotDelete` on production.
13. Operations → Policies — assignments scoped, results populating.
14. Operations → Machine Configuration — baselines reporting Compliant / known-Non-compliant.
15. Operations → Run command — one test command round-trips.
16. Operations → SQL Server Configuration — only if SQL is installed.
17. Operations → Updates — periodic assessment on, schedule attached.
18. Operations → Inventory — software list populates.
19. Operations → Change tracking — DCR has ChangeTracking data source.
20. Licenses → Windows Server — Licensed, Azure benefits activated.
21. Windows management → Remote Support — leave off until needed.
22. Windows management → Windows Admin Center — extension installed, test connect.
23. Windows management → Azure Site Recovery — only if box is in DR scope.
24. Windows management → Best Practices Assessment — run once, review High findings.
25. Windows management → Azure File Sync — only on file servers.
26. Monitoring → Insights — enabled with charts.
27. Monitoring → Logs — Heartbeat row from this machine in last 5 min.
28. Monitoring → Workbooks — pin one or two templates.
29. Automation → CLI / PS — copy snippets you'll automate from.
30. Automation → Tasks — optional, skip if you orchestrate elsewhere.
31. Help → Resource health — Available.
32. Help → Support + Troubleshooting — know where the log bundle command lives before you need it.

When step N is red, the **If broken** subsection of section N above tells you the exact log path, command, or RBAC fix.
