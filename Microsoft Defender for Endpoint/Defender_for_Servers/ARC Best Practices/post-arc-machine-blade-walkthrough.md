# Post Azure Arc Onboarding — Per-Machine Blade Walkthrough

Scope: a single Arc-enabled server you just onboarded (Windows or Linux). This walks the **per-machine** left-nav in **portal.azure.com → Azure Arc → Machines → \<server\>** in the exact order Azure shows the tiles, and for each one answers:

1. **What this blade does**
2. **What to check after onboarding**
3. **How to troubleshoot when it's wrong**

The companion document [`post-arc-onboarding-checklist.md`](./post-arc-onboarding-checklist.md) covers the **service-level** Arc blade (Overview / Infrastructure / Data services / Licenses / Migration etc.) and the things outside Arc entirely (Defender for Cloud, Sentinel, AMA, Update Manager, KQL). This page is **machine-only**.

---

## 0. Before you open the portal — agent sanity check on the box

On the machine itself:

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

You want `Agent Status: Connected`, agent version recent, and every endpoint in `azcmagent check` returning **reachable**. If the agent can't reach Azure, nothing in the portal blades below will work — fix this first.

Log paths to know:

| OS | Agent log | Extension manager log | Per-extension logs |
|---|---|---|---|
| Windows | `C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log` | `C:\ProgramData\GuestConfig\gc_agent_logs\gc_agent.log`, `gcm.log` | `C:\Packages\Plugins\<publisher>.<extension>\<version>\Status\` and `…\Logs\` |
| Linux | `/var/opt/azcmagent/log/himds.log` | `/var/lib/GuestConfig/gc_agent_logs/gc_agent.log` | `/var/lib/waagent/<publisher>.<extension>-<version>/status/` and `…/CommandExecution.log` |

---

# Top-level items (shown at the top of the machine blade)

## Overview

**What it does.** Lands you on the machine summary. Shows connection status, last heartbeat, OS, agent version, resource group, subscription, region, and the auto-discovered hardware/network details.

**What to check after onboarding.**

- **Status: Connected** (not *Disconnected*, *Expired*, or *Error*).
- **Last seen** is within the last 5 minutes.
- **OS name / version** detected correctly.
- **Subscription** and **Resource group** match your placement plan.
- **Agent version** matches current release (compare against [agent release notes](https://learn.microsoft.com/azure/azure-arc/servers/agent-release-notes)).

**Troubleshoot.**

- *Disconnected* — agent service down or network broken. On the box: `Get-Service himds` (Windows) / `systemctl status himds` (Linux). Then `azcmagent check`. Open `himds.log`.
- *Expired* — onboarding token expired; reconnect with `azcmagent connect ...`.
- Old agent version — update with the MSI/`apt`/`yum` package; no re-onboarding needed.

---

## Activity log

**What it does.** Azure Resource Manager audit trail for everything that has happened to this Arc resource (extension installs, license toggles, RBAC changes, tag edits, delete attempts).

**What to check after onboarding.**

- Filter the last 24 hours, look for `Microsoft.HybridCompute/machines/write` (the onboarding) and `Microsoft.HybridCompute/machines/extensions/write` (anything that auto-deployed afterwards — AMA, MDE.Windows, etc.).
- Every entry should be **Succeeded**. Note the **Correlation ID** of anything that failed — you'll use it in a support ticket.

**Troubleshoot.**

- Click a failed entry → **JSON** tab → look at `properties.statusMessage` and `properties.error`.
- This is your single source of truth for "who pushed what extension when" — Defender for Cloud auto-provisioning, an Azure Policy assignment, or a human all show up here distinctly under **Caller** and **Authorization → Action**.

---

## Access control (IAM)

**What it does.** RBAC at the machine scope.

**What to check after onboarding.**

- The identity that onboarded the box has at least **Azure Connected Machine Onboarding** at the resource-group scope.
- Admins who need to push extensions need **Azure Connected Machine Resource Administrator** (or **Contributor**).
- Users who only need to see telemetry need **Monitoring Reader**.
- No accidental **Owner** assignments at the machine scope.

**Troubleshoot.**

- Extension install denied → check IAM at the **resource-group or subscription** scope, not just the machine; extension writes inherit from above.
- Auto-deploy from Defender for Cloud failing → the Defender for Cloud service principal needs **Azure Connected Machine Resource Administrator** at the subscription scope.

---

## Tags

**What it does.** Resource tags on the Arc machine resource (separate from any OS-level tags).

**What to check after onboarding.**

Apply your standard tag set **before** wiring anything else. Many downstream features target by tag:

- `environment` (`prod`/`test`/`dev`)
- `owner` (team or DL)
- `costcenter`
- `criticality`
- `patchgroup` (Update Manager schedules)
- `dcrAssociation` (which DCR to attach)

**Troubleshoot.**

- Update Manager schedule never picks the box up → wrong `patchgroup` tag or no tag.
- AMA never gets a DCR → DCR association policy is keyed on a tag the machine doesn't have.

---

## Diagnose and solve problems

**What it does.** Built-in self-help diagnostics specifically for Arc — connectivity tests, agent health, extension health, and common-problem playbooks. It's the in-portal version of `azcmagent check`.

**What to check after onboarding.**

- Run **Connectivity issues** — confirms all required FQDNs are reachable from the box (only works if the agent is still up enough to respond).
- Run **Extension issues** — surfaces failed extensions and decodes the most common error codes.

**Troubleshoot.**

- This blade often shows the human-readable explanation for an error code that's cryptic in the extension status (e.g., translates `9` to "agent could not reach Guest Configuration endpoint").
- If the blade itself fails to load data, the agent is offline — go back to **Overview** and fix Connected status first.

---

## Monitor

**What it does.** Shortcut into Azure Monitor scoped to this machine. Shows alerts, metrics, and "Insights" enablement.

**What to check after onboarding.**

- **Insights** tab should say *Insights enabled* once AMA is installed and a VM Insights DCR is associated.
- No active **Critical** or **Error** alerts.

**Troubleshoot.**

- *Insights not enabled* even though AMA is **Succeeded** — the machine isn't associated with a VM Insights-flavored DCR. Go to **Azure Monitor → Data Collection Rules** and add the machine as a target.

---

## Resource visualizer

**What it does.** Renders a graph of the Arc machine resource and its child resources (extensions, license link, private link associations).

**What to check after onboarding.**

- Each expected extension appears as a child node.
- Lines connecting to a private link scope, ESU license, or AAMPLS exist if you configured them.

**Troubleshoot.**

- An extension you expect is missing from the graph → it never deployed at all (check **Settings → Extensions** and **Activity log**); this is different from "deployed but failed."

---

# Settings group

## Settings → Connect

**What it does.** Connectivity mode (Public endpoint vs Private link), proxy settings, and the reconnect command if the agent's onboarding token expired.

**What to check after onboarding.**

- **Connectivity method** matches your design: **Public endpoint** for normal deployments, **Private link scope** for restricted networks.
- If using a proxy: `azcmagent config list` on the box confirms `proxy.url` is set.
- For Gov/IL5: endpoints should be `*.his.arc.azure.us`, `*.guestconfiguration.azure.us` — not `.com`. (See sibling page [`MDE_ARC_Connectivity_Verify.md`](../MDE_ARC_Connectivity_Verify.md).)

**Troubleshoot.**

- Switched to Private link but agent still hits public endpoints → on the box run:
  ```powershell
  azcmagent config set connection.type private
  Restart-Service himds, gcarcservice, ExtensionService   # Linux: himdsd, gcad, extd
  ```
- Proxy URL set but agent still fails → check `proxy.bypass`. The Arc agent should bypass `ArcData,Guestconfig` so it stays inside the proxy for everything else.

---

## Settings → Security

**What it does.** Two things live here in the current portal: the machine's **system-assigned managed identity** (Object ID, used for token requests from inside the OS) and the machine's **security posture summary** (Defender for Cloud signals if Plan 2 is enabled).

**What to check after onboarding.**

- **System-assigned managed identity → Object (principal) ID** is present and non-empty.
- If you intend any script on the box to call Azure, grant that MSI scoped roles (e.g., `Key Vault Secrets User` on a specific vault) **here is not the place** — do it on the target resource. This blade just shows you the identity to grant to.
- Defender for Cloud status, if visible, is **Healthy** with no high-severity recommendations outstanding.

**Troubleshoot.**

- No Object ID → MSI never provisioned; usually a Hybrid Connectivity Service issue. Re-run `azcmagent connect` to refresh.
- Scripts on the box can't get a token → they must call the Arc-specific endpoint, **not** the Azure VM IMDS:
  - `http://localhost:40342/metadata/identity/oauth2/token?api-version=2020-06-01&resource=https://management.azure.com/`
  - First call returns 401 with a `Www-Authenticate` header pointing at a one-time challenge file; the script reads that file and re-calls with the challenge. This is documented as the Arc "identity challenge" flow.

---

## Settings → Extensions

**What it does.** Lists every Arc VM extension installed on this machine and lets you install / upgrade / uninstall.

**What to check after onboarding.**

Expected extensions on a typical P2 Windows server (Linux equivalents in parentheses):

| Extension | Provisioning state should be |
|---|---|
| `AzureMonitorWindowsAgent` (`AzureMonitorLinuxAgent`) | Succeeded |
| `MDE.Windows` (`MDE.Linux`) — if Defender for Cloud auto-deploy is on | Succeeded |
| `AzurePolicyforWindows` (`ConfigurationforLinux`) | Succeeded |
| `ChangeTracking-Windows` (`ChangeTracking-Linux`) — if you enabled Change Tracking | Succeeded |
| `WindowsAdminCenter` — optional but recommended | Succeeded |

**Troubleshoot.**

- Extension stuck in **Creating** / **Transitioning** for over an hour → the extension manager never picked up the work. Look at `gcm.log` (Windows) / extension manager log on Linux.
- Extension shows **Failed** → click the extension → read the **Status message** verbatim. Then open the per-extension log:
  - Windows: `C:\Packages\Plugins\<publisher>.<extension>\<version>\Status\*.status` and `…\Logs\*.log`.
  - Linux: `/var/lib/waagent/<publisher>.<extension>-<version>/status/` and `CommandExecution.log`.
- Exit code reference (handler script return codes): `0` success, `1` generic failure, `9` Guest Config endpoint unreachable, `51` not supported on this OS, `52` missing dependency, `53` configuration error.

---

## Settings → Properties

**What it does.** Read-only resource metadata: ARM resource ID, location, kind, agent version, Azure AD tenant ID, machine ID (GUID), OS profile, vm.fqdn, public key.

**What to check after onboarding.**

- **Operating system** detected correctly (matters for which extension SKU gets pushed — Win vs Linux).
- **Cloud provider** reflects reality (`Other` for true on-prem, `AWS`/`GCP` for cross-cloud).
- **vm.fqdn** matches what the machine reports.
- **Resource ID** is the canonical ID you'll need for Azure Policy / Sentinel queries / support tickets.

**Troubleshoot.**

- OS detected as Linux on a Windows box (or vice-versa) → agent installer mismatch; re-run `azcmagent connect` with the correct installer.
- Wrong tenant / subscription → the box was onboarded with the wrong service principal or token. Disconnect (`azcmagent disconnect`) and re-onboard.

---

## Settings → Locks

**What it does.** Azure RM resource locks (Read-only, Delete) at the machine scope.

**What to check after onboarding.**

- On production: apply a `CanNotDelete` lock so the Arc resource (and the MDE/AMA telemetry pipeline it backs) cannot be accidentally removed.

**Troubleshoot.**

- Can't decommission a box → check for locks here and at the parent resource group.

---

# Operations group

## Operations → Policies

**What it does.** Azure Policy compliance state for this specific machine. Shows assigned initiatives and per-policy results.

**What to check after onboarding.**

- Compliance shows results for the initiatives you target Arc with — typically *Azure Security Benchmark*, *Defender for Cloud — recommendations*, *Deploy AMA*, *Deploy MDE*, *Configure DCR*, *Enable Guest Configuration*, etc.
- First scan after onboarding can take up to 60 minutes to populate.

**Troubleshoot.**

- All policies show **Not registered / Not applicable** → the policy assignment scope doesn't include this resource group; or the resource type filter in the policy excludes `Microsoft.HybridCompute/machines`.
- Some policies show **Non-compliant** with no remediation task → assignments using *DeployIfNotExists* need a managed identity with `Contributor` at the scope. Create a remediation task from the assignment.

---

## Operations → Machine Configuration

**What it does.** The Arc equivalent of in-OS policy — Guest Configuration. Runs DSC/InSpec content inside the OS to assert state (audit *or* enforce).

**What to check after onboarding.**

- Lists the assigned Guest Configuration packages, each with **Compliance** = *Compliant* / *Non-compliant* / *Pending*.
- For Defender for Cloud baselines (`AzureWindowsBaseline`, `AzureLinuxBaseline`) expect the first scan ~30–60 min after the `AzurePolicyforWindows` / `ConfigurationforLinux` extension installs.

**Troubleshoot.**

- Stays *Pending* indefinitely → the Guest Configuration extension is missing or failed (`Settings → Extensions`). Open `gc_agent.log`.
- *Non-compliant* with no detail → click the assignment to see which specific rule(s) failed; remediate on-box or exclude in the assignment.

---

## Operations → Run command (preview)

**What it does.** Push a short script (PowerShell on Windows, bash on Linux) to the machine via the `RunCommandHandlerWindows` / `RunCommandHandlerLinux` extension, with output returned to the portal.

**What to check after onboarding.**

- The handler extension shows **Succeeded** on the **Extensions** blade — without it, the **Run command** blade has nothing to talk to.
- Test once with a benign command: `Get-Date` (Windows) or `uptime` (Linux). Output should return in under a minute.

**Troubleshoot.**

- Command never returns or errors immediately → handler extension not installed, or the box's outbound network can't reach `*.guestconfiguration.azure.com` / `.us`.
- Output truncated → built-in 4 KB cap per run; for larger output have the script write to a blob and emit a SAS URL.

---

## Operations → SQL Server Configuration

**What it does.** Visible only when the Arc agent has detected a SQL Server instance on the box. Manages the Arc-enabled SQL Server features: license type, Best Practices Assessment, automated backups, Entra auth.

**What to check after onboarding (if SQL is present).**

- Each instance shows up with the right license type (Paid / PAYG / SA / Developer).
- **Best Practices Assessment** enabled.
- **Automated backups** target an Azure Blob container (only if you want this).

**Troubleshoot.**

- Instance not detected → SQL discovery requires the agent service account to read SQL registry keys and connect to the instance. Confirm `azcmagent` has local admin or the SQL discovery exclusion isn't set.
- Backups failing → confirm the storage account has the Arc machine's MSI granted `Storage Blob Data Contributor`.

---

## Operations → Updates

**What it does.** This machine's pane in **Azure Update Manager** — current patch compliance, pending updates, scheduled deployments.

**What to check after onboarding.**

- **Periodic assessment** turned on (one-time setting; the agent then reports patch state every ~24h).
- A **maintenance configuration** (schedule) is attached, or you're using on-demand `One-time update`.
- First **Compliance assessment** completes within a few hours (Windows) or up to a day (Linux).

**Troubleshoot.**

- *No assessment data* — the box isn't licensed for Azure Update Manager. For Arc machines this requires **Azure Benefits = Licensed** under Software Assurance, **or** explicit PAYG.
- Patches stuck *Pending* — the WSUS / repo the box uses isn't healthy; UM doesn't fix upstream patch infra, it only orchestrates.

---

## Operations → Inventory

**What it does.** Software / files / Windows services / Linux daemons inventory, fed by the **ChangeTracking** extension and AMA.

**What to check after onboarding.**

- The **ChangeTracking-Windows** / **ChangeTracking-Linux** extension shows **Succeeded**.
- Inventory page lists installed software within 30–60 minutes.

**Troubleshoot.**

- Extension Succeeded but Inventory is empty → the **DCR associated with this machine has no ChangeTracking data source**. Edit the DCR, add `Microsoft-ConfigurationData` (or the ChangeTracking data source through the portal wizard), save.
- Linux daemons missing → the ChangeTracking content for Linux only covers SysV / systemd services; non-standard init systems aren't inventoried.

---

## Operations → Change tracking

**What it does.** Same data source as Inventory, but the "what changed and when" view: file, registry, software, service start/stop events over time.

**What to check after onboarding.**

- Within 60 minutes you can see Windows services flipping state, software install/uninstall, and registry changes you configured to watch.
- File/registry tracking is opt-in via the DCR's `extensionSettings` — empty by default.

**Troubleshoot.**

- *No changes detected* — either nothing changed (most common!), or the DCR isn't actually associated. Check **Azure Monitor → DCR → Resources** confirms this machine is in the target list.

---

# Licenses group

## Licenses → Windows Server

**What it does.** Per-machine license attestation for Windows Server. Determines whether the box qualifies for Software Assurance benefits, ESU eligibility, and which Azure Benefits unlock.

**What to check after onboarding.**

- **License status** = *Licensed*.
- **Activate Azure benefits** = checked.
- **License type** matches reality: *Paid* (SA), *Subscription* (cloud subscription license), *PAYG*, or *Developer / Enterprise Agreement*.

**Troubleshoot.**

- License toggle won't enable → tenant doesn't have the corresponding offer (e.g., Server SA) attested. Talk to your EA / licensing admin first.
- ESU patches not flowing → on the **service-level** Arc blade (`Licenses → Extended Security Updates - Windows Server`) you have to **link** the box to an ESU license resource. The per-machine blade just shows the result of that link.

---

# Windows management group

(Most of these are preview today and only meaningful on Windows.)

## Windows management → Remote Support (Preview)

**What it does.** Time-bounded remote-help session brokered through Arc — Microsoft engineers or an internal helper connect to the OS without VPN/jump host.

**What to check after onboarding.**

- Only enable when you actually need a session; sessions are auditable in **Activity log**.

**Troubleshoot.**

- Session fails to start → outbound to the Hybrid Connectivity Service endpoint blocked; same FQDNs as the `Connect → SSH` flow.

---

## Windows management → Windows Admin Center (preview)

**What it does.** Browser-based RDP-less server management (services, registry, files, certificates, networking, Defender configuration, etc.) tunneled through the Arc agent.

**What to check after onboarding.**

- Install the `WindowsAdminCenter` extension on the machine.
- Hit **Connect** — first launch takes ~30s while WAC initializes inside the agent.
- The signed-in admin needs **Windows Admin Center Administrator Login** RBAC on the Arc resource.

**Troubleshoot.**

- *Connection failed* → outbound to `*.waconazure.com` (`.us` in Gov) is blocked.
- *Access denied* → missing RBAC; or local OS account doesn't exist (WAC authenticates the connecting admin against the OS, not just Azure).

---

## Windows management → Azure Site Recovery configuration (preview)

**What it does.** Enables disaster-recovery replication for the Arc machine into Azure.

**What to check after onboarding.**

- Only configure for boxes that are in scope for DR. Replication has cost and ongoing bandwidth implications — be deliberate.

**Troubleshoot.**

- Initial replication never starts → check the Recovery Services Vault region and that the Mobility extension is installed.

---

## Windows management → Best Practices Assessment (preview)

**What it does.** Runs Microsoft's BPA rules against the OS and any installed Windows roles, returns findings.

**What to check after onboarding.**

- Run the assessment once, sort by severity, fix or document each High finding.

**Troubleshoot.**

- Empty / no results → BPA agent component not installed or the run wasn't scheduled. Trigger manually from the blade.

---

## Windows management → Azure File Sync (Preview)

**What it does.** Enables Azure File Sync agent registration if the box is acting as a file server.

**What to check after onboarding.**

- Only relevant for file servers. Skip on app/DB/web servers.

**Troubleshoot.**

- Registration fails → AFS agent install on-box failed; check `%ProgramFiles%\Azure\StorageSyncAgent` logs.

---

# Monitoring group

## Monitoring → Insights

**What it does.** VM Insights view: perf counters, processes, dependencies (the Dependency Agent / Map feature), all powered by AMA + the VM Insights DCR.

**What to check after onboarding.**

- *Enabled* and showing CPU / memory / disk / network charts within an hour of AMA install.
- Map tab populates within ~30 minutes if the Dependency Agent / Map extension is installed.

**Troubleshoot.**

- *Insights not enabled* → AMA is installed but no VM Insights DCR is associated. Fix: associate a DCR that includes the `Microsoft-InsightsMetrics` data stream.
- Map tab empty → Dependency Agent missing, or process-level visibility turned off in DCR.

---

## Monitoring → Logs

**What it does.** Log Analytics workspace queries scoped to this machine.

**What to check after onboarding.**

- `Heartbeat | where Computer == "<name>" | top 1 by TimeGenerated` returns a row in the last 5 minutes.
- The expected tables have data: `Perf`, `Event`, `Syslog` (Linux), `SecurityEvent` (if a security DCR is attached).

**Troubleshoot.**

- No `Heartbeat` rows → AMA isn't talking to the workspace. Confirm AMA extension state, DCR association, and that the DCE (if private) is reachable.
- Tables missing entirely → DCR has no data sources for those tables; or you're querying the wrong workspace.

---

## Monitoring → Workbooks

**What it does.** Saved interactive reports scoped to this machine. Useful templates ship for performance, security baseline, and patch compliance.

**What to check after onboarding.**

- Pin one or two workbooks (e.g., *Performance Analysis*, *Security Baseline*) as a quick at-a-glance view.

**Troubleshoot.**

- Workbook empty → underlying tables empty; fix `Logs` first.

---

# Automation group

## Automation → CLI / PS

**What it does.** Auto-generates Azure CLI and Azure PowerShell snippets for managing this exact resource (set tags, install extension, update license type, etc.).

**What to check after onboarding.**

- Use it to script repeatable actions across many machines — copy the snippet, swap in a parameterized loop.

**Troubleshoot.**

- Snippet fails when you run it → almost always missing module (`Az.ConnectedMachine`) or missing RBAC at the scope.

---

## Automation → Tasks

**What it does.** Scheduled / triggered automation against this resource (early preview as of 2026).

**What to check after onboarding.**

- Optional. Most teams orchestrate from Azure Automation, Logic Apps, or GitHub Actions instead.

**Troubleshoot.**

- Task fails → check the run history; it surfaces the underlying Logic App / runbook error.

---

# Help group

## Help → Resource health

**What it does.** Azure-side health signal for this Arc resource — Available, Unavailable, Unknown.

**What to check after onboarding.**

- *Available*.
- If *Unknown*, the agent hasn't checked in recently — heartbeat lag, not necessarily a failure.

**Troubleshoot.**

- *Unavailable* with a reason of *Disconnected* → agent service down or network broken on the box. Go back to **0. Sanity check**.
- Persistent *Unknown* — agent is up but Hybrid Connectivity Service hasn't recorded a recent heartbeat; check outbound to `*.his.arc.azure.com` / `.us`.

---

## Help → Support + Troubleshooting

**What it does.** Self-service support for this machine: diagnostic logs collector, common problem playbooks, and the entry point to open a Microsoft support case pre-scoped to this resource.

**What to check after onboarding.**

- You don't routinely use this blade — it's an "on demand" tool when something breaks.

**Troubleshoot — log collection.**

When opening a support ticket, attach the agent log bundle:

```powershell
# Windows
azcmagent logs --full --output "C:\Temp\arc-logs.zip"
```

```bash
# Linux
sudo azcmagent logs --full --output /tmp/arc-logs.tar.gz
```

That bundle contains `himds.log`, the extension manager logs, Guest Configuration logs, and the most recent per-extension logs — everything Microsoft will ask for on call one.

---

# Per-machine post-onboarding checklist (one screen)

Run through this in order, the first time you touch a new Arc machine:

1. **On the box:** `azcmagent show` = Connected, `azcmagent check` = all green.
2. **Overview:** Connected, Last seen current, OS correct.
3. **Tags:** standard tag set applied.
4. **Access control (IAM):** least-privilege roles assigned; no Owner at machine scope.
5. **Settings → Connect:** correct connectivity method (Public vs Private link) for your environment.
6. **Settings → Security:** MSI Object ID present.
7. **Settings → Extensions:** all expected extensions Succeeded. Run the [unhealthy-extensions KQL](./post-arc-onboarding-checklist.md) for a fleet view.
8. **Settings → Properties:** OS, tenant, subscription, FQDN correct.
9. **Settings → Locks:** `CanNotDelete` on production.
10. **Operations → Policies:** compliance results populating.
11. **Operations → Machine Configuration:** baseline assignment showing Compliant or known-Non-compliant.
12. **Operations → Run command:** one test command round-trips successfully.
13. **Operations → Updates:** periodic assessment on, maintenance schedule attached.
14. **Operations → Inventory + Change tracking:** software list populated, DCR data source confirmed.
15. **Licenses → Windows Server:** Licensed, Azure benefits activated.
16. **Monitoring → Insights:** enabled, charts populated.
17. **Monitoring → Logs:** `Heartbeat` row from this machine in the last 5 minutes.
18. **Help → Resource health:** Available.

When any step above is red, the **Troubleshoot** subsection of that blade above tells you the next log to open.
