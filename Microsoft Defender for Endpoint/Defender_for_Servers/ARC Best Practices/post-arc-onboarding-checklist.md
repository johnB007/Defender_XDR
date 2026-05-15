# Post Azure Arc Onboarding — Verification & Best-Practice Checklist

Scope: machines onboarded **manually** (interactive `azcmagent connect` or generated install script) to Azure Arc, mixed Windows Server + Linux, with **Microsoft Entra ID P2** and (assumed) **Defender for Servers P2** available.

The Arc onboarding script only installs and registers the **Connected Machine agent (azcmagent)**. Everything below is what you still have to enable, verify, or wire up *after* the script finishes — almost all of it lives in blades outside the onboarding flow.

---

## 0. Sanity check the agent itself (do this first on every box)

On the machine:

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

You want:

- `Agent Status: Connected`
- `Agent version` current (compare to [What's new](https://learn.microsoft.com/azure/azure-arc/servers/agent-release-notes))
- `azcmagent check` — all endpoints reachable (especially `*.guestconfiguration.azure.com`, `*.his.arc.azure.com`, `*.waconazure.com`, `download.microsoft.com`).

In the portal: **Azure Arc → Machines → \<server\> → Overview** should show **Status: Connected** and a recent **Last seen** timestamp.

---

## 1. Resource hygiene (Overview / Tags / Properties / Locks)

| Blade | What to set / verify |
|---|---|
| **Overview** | Status = Connected, OS detected correctly, correct subscription + resource group. |
| **Tags** | Apply your standard tags (`environment`, `owner`, `costcenter`, `criticality`, `patchgroup`). Many downstream policies and Update Manager schedules target by tag — do this before you wire anything else up. |
| **Properties** | Confirm **Operating system**, **Cloud provider** (will say "Other" / on-prem), **Domain**, **Public key**. |
| **Locks** | Optional `CanNotDelete` lock on production servers so the Arc resource can't be removed accidentally. |
| **Access control (IAM)** | Grant least-privilege roles. Common ones: *Azure Connected Machine Onboarding*, *Azure Connected Machine Resource Administrator*, *Monitoring Reader/Contributor*. Avoid Owner. |

---

## 2. Licensing — Windows Server only

**Settings → Licenses → Windows Server**

- **License status** = Licensed.
- **Activate Azure benefits** checked — this attests Software Assurance / subscription licensing and is what unlocks:
  - Azure Update Manager at no per-server charge for Arc machines covered by SA.
  - Extended Security Updates (ESU) eligibility for Server 2012 / 2012 R2 (and the Server 2016/2019 ESU program when those reach EOS).
  - Azure Policy guest configuration at no charge.
- If a server is **not** under SA, use **Pay-as-you-go with Azure** instead — but the machine has to be unlicensed (KMS/MAK removed) first, which is why your screenshot shows the warning.
- For Server 2012 / 2012 R2 boxes specifically, also visit **Azure Arc → Extended Security Updates** and link the machine to an ESU license.

---

## 3. Connectivity & private networking (Settings → Connect)

- Decide **Public endpoint** vs **Private Link Scope (AMPLS-style "Azure Arc Private Link Scope")**. If you committed to private, create the scope and associate the machines; the agent will then resolve `*.his.arc.azure.com`, guest config, and extension endpoints over private IPs.
- Configure proxy if you use one: `azcmagent config set proxy.url http://proxy:8080` and proxy bypass for the required endpoints.

---

## 4. Defender for Servers Plan 2 (Microsoft Defender for Cloud)

This is where most of the P2 value lives, and **none of it gets turned on by the Arc onboarding script**.

1. **Defender for Cloud → Environment settings → \<subscription\> → Defender plans**
   - Turn **Servers** ON, set plan to **Plan 2**.
   - Under the Servers row → **Settings**, verify these are **On**:
     - **Vulnerability assessment for machines** → *Microsoft Defender Vulnerability Management* (the integrated MDVM, not the legacy Qualys).
     - **Endpoint protection** (Defender for Endpoint integration / MDE.Windows / MDE.Linux extension auto-deploy).
     - **Agentless scanning for machines** (P2 only — gives you software inventory + secrets scanning without an agent on the disk; for Arc this needs the machine to be a VM whose disk Defender can snapshot, or it falls back to MDE telemetry).
     - **File Integrity Monitoring** (P2 only, AMA-based).
     - **Log Analytics agent / Azure Monitor Agent autoprovisioning** — pick **AMA** (MMA is retired).
2. **Defender for Cloud → Environment settings → \<subscription\> → Data collection** — confirm a **Log Analytics workspace** is selected (yours, not the default) and security events level (Minimal / Common / All).
3. **Defender for Cloud → Inventory** — your Arc machines should appear within ~30 min with a Defender plan badge. Investigate any with "Not covered".
4. **Defender for Cloud → Recommendations** — work the list; first ones to expect on fresh Arc boxes:
   - "Machines should have a vulnerability assessment solution"
   - "Endpoint protection should be installed"
   - "Azure Monitor Agent should be installed"
   - "System updates should be installed"
5. **MDE onboarding sanity check** on the box:
   - Windows: `Get-MpComputerStatus` → `AMRunningMode` should be `Normal` or `EDR Block Mode`; `Get-Service Sense` running.
   - Linux: `mdatp health` → `healthy : true`, `org_id` populated.

---

## 5. Monitoring (Azure Monitor Agent + DCRs)

The AMA extension can be auto-deployed by Defender, but if you want logs/perf/Sentinel you must explicitly create **Data Collection Rules**.

- **Monitor → Data Collection Rules → + Create**
  - Platform: Windows / Linux (one DCR per platform is cleanest).
  - Resources: pick the Arc machines (they show up alongside Azure VMs).
  - Data sources you'll typically want:
    - Windows Event Logs (Security, System, Application, Microsoft-Windows-Sysmon/Operational if you use Sysmon).
    - Performance counters (Processor, Memory, LogicalDisk, Network).
    - Linux Syslog (auth, daemon, kern, syslog at LOG_INFO+).
    - Linux performance.
  - Destination: your Log Analytics workspace.
- On the Arc machine blade: **Monitoring → Insights → Enable** → confirms VM Insights DCR + Dependency agent.
- **Monitoring → Logs** — run `Heartbeat | where Computer == "DC007" | take 5` to confirm ingestion. If empty after 15 min, check the AzureMonitorWindowsAgent / AzureMonitorLinuxAgent extension status under **Settings → Extensions**.

---

## 6. Microsoft Sentinel

- **Sentinel → Data connectors**: enable
  - *Windows Security Events via AMA* (uses the same DCR pattern above). Add the **Windows Firewall** data source to that same DCR so the `Microsoft-Windows-Windows Firewall With Advanced Security/Firewall` and `.../ConnectionSecurity` event logs (and the `MicrosoftWindowsWindowsFirewall` provider) ship into Sentinel alongside Security/System/Application — one DCR, one AMA, one connector.
  - *Microsoft Defender for Cloud* (alerts).
  - *Microsoft Defender XDR* if MDE is connected.
  - *Syslog via AMA* / *Common Event Format via AMA* for Linux.
- Verify analytics rules and workbooks see the new hosts (`Heartbeat`, `SecurityEvent`, `Syslog` tables).

---

## 7. Azure Update Manager

- **Azure Update Manager → Machines** — Arc machines appear automatically once connected.
- For each new box (or via a tag-based dynamic scope):
  - Run **Check for updates** (one-time assessment).
  - Create / attach a **Maintenance configuration** (schedule, reboot setting, classifications, pre/post scripts).
  - For Linux, confirm the package manager (apt/yum/dnf/zypper) is detected on the **Updates** tab.
- Set **Patch orchestration** = *Customer Managed Schedules (Preview)* via Azure Policy "Configure periodic checking for missing system updates" so assessments run every 24h without you scheduling them.

---

## 8. Machine Configuration / Guest Configuration (Operations → Machine Configuration)

This is the Arc equivalent of Azure Policy *inside* the OS. Free for Arc machines with SA / PAYG.

- **Policy → Definitions** — assign built-in initiatives that matter:
  - *\[Preview\]: Windows machines should meet requirements for the Azure compute security baseline* (CIS-aligned).
  - *Linux machines should meet requirements for the Azure compute security baseline*.
  - *Configure time zone on Windows machines* (if applicable).
  - *Deploy prerequisites to enable Guest Configuration policies on virtual machines* — required, also covers Arc.
- After ~30–60 min, **Machine Configuration** blade on the server shows compliance per assignment. Remediate or exempt.

---

## 9. Extensions you'll commonly want (Settings → Extensions)

Either deploy per-machine here, or (better) via Azure Policy "Deploy if not exists" to the resource group / subscription:

| Extension | Purpose | Win | Linux |
|---|---|:-:|:-:|
| `AzureMonitorWindowsAgent` / `AzureMonitorLinuxAgent` | AMA for logs/metrics | ✓ | ✓ |
| `MDE.Windows` / `MDE.Linux` | Defender for Endpoint | ✓ | ✓ |
| `ChangeTracking-Windows` / `-Linux` | File/registry/software change tracking (AMA-based) | ✓ | ✓ |
| `AzureSecurityWindowsAgent` / `AzureSecurityLinuxAgent` | Defender for Cloud agent | ✓ | ✓ |
| `WindowsAdminCenter` | Browser-based RDP-less admin from the portal | ✓ | – |
| `AzurePolicyforWindows` / `ConfigurationforLinux` | Guest configuration engine | ✓ | ✓ |
| `KeyVaultForWindows` / `KeyVaultForLinux` | Auto-rotate certs from Key Vault | ✓ | ✓ |
| `RunCommandHandlerWindows` / `Linux` | Portal Run Command (preview blade) | ✓ | ✓ |
| `CustomScriptExtension` | Ad-hoc bootstrap scripts | ✓ | ✓ |

Verify each one shows **Provisioning state: Succeeded**. Failed extensions are the #1 source of "Defender thinks the box is unhealthy" tickets.

---

## 10. Identity, RBAC, and the system-assigned managed identity

- Every Arc machine automatically gets a **system-assigned managed identity**. Check **Settings → Identity** → Object (principal) ID is present.
- Use that identity (not stored secrets) when scripts on the box need to talk to Azure:
  - Grant it scoped roles (e.g., `Key Vault Secrets User` on a specific vault, `Storage Blob Data Reader` on a container).
  - On the box, fetch a token from `http://localhost:40342/metadata/identity/oauth2/token` (Arc's IMDS-equivalent endpoint — different port than Azure VMs).
- Because you have **Entra ID P2**, also turn on for the Arc machine principal where relevant:
  - **Privileged Identity Management** for any human admins assigned roles on the Arc resources.
  - **Conditional Access** policies covering Azure management (the agent itself is exempt, but admin sign-ins are not).
  - **Identity Protection** risk policies for the admin accounts.
  - For Windows Server boxes that you want **Entra-joined / Entra login enabled**, that's a separate extension (`AADLoginForWindows` is Azure-VM-only today; for Arc Windows Servers SSH-with-Entra is via the `SshPosh`/`AADSSHLoginForLinux` model on Linux only — confirm current support before relying on it).

---

## 11. SSH / Windows Admin Center over Arc (no inbound ports)

P2 plan or not, this is a huge quality-of-life win:

- **Settings → Connect → SSH** (or run `az ssh arc --name DC007 --resource-group <rg>`): tunneled SSH/RDP through the Arc agent — no public IP, no VPN.
- **Windows management → Windows Admin Center**: deploy the WAC extension, then manage the server in-browser from the portal.
- For both, your admin account needs **Virtual Machine Local User Login** (or Administrator Login) RBAC on the Arc resource.

---

## 12. Backup, DR, inventory, change tracking

- **Operations → Inventory** and **Change tracking** — turn on; both now use AMA + DCR. Useful for audit and for spotting drift after patching.
- **Azure Backup for Arc-enabled servers** (MARS agent or workload backup for SQL on Arc) is a separate install — not done by the Arc agent.
- If these are domain controllers (your `DC007` naming suggests yes), make sure your existing AD backup strategy is intact; Arc doesn't change it but Update Manager reboots can surprise you.

---

## 13. SQL Server on the box? (Operations → SQL Server Configuration)

If any of these servers run SQL Server, the Arc agent auto-discovers instances and registers them as **Arc-enabled SQL Server** resources. Then:

- License each instance (PAYG or BYOL with SA) — same Azure Benefits attestation pattern as the Windows Server license.
- Enable **Defender for SQL servers on machines** in Defender for Cloud (separate plan toggle).
- Turn on **Best practices assessment**, **Automated backups to Azure Blob**, and **Microsoft Entra authentication for SQL** from the SQL – Azure Arc resource blade.

---

## 14. Alerts you should create on day one

In **Monitor → Alerts** (or Defender for Cloud → Workflow automation):

- **Heartbeat missing > 15 min** (Arc machine offline). Use the `Heartbeat` table or Resource Health signal `ConnectedMachine - Disconnected`.
- **Agent version older than N-2** (use Resource Graph + workbook).
- **Defender for Cloud high-severity alerts** on the subscription, routed to a Logic App / Action Group / Sentinel incident.
- **Update Manager — pending security updates > 0 for > 7 days**.
- **Extension provisioning failed** (`Microsoft.HybridCompute/machines/extensions` Activity Log).

---

## 15. Quick "did I miss anything?" KQL pack

Run these from **Microsoft Sentinel → Logs** (or the Defender XDR **Advanced Hunting** blade when querying the same workspace). The Resource-Graph queries use the cross-service `arg("")` function so they run inside the Sentinel workspace — you don't need to switch to Azure Resource Graph Explorer. Every query is OS-aware so Windows and Linux Arc machines both surface.

```kusto
// Arc inventory + agent + OS split (Windows / Linux)
arg("").resources
| where type == "microsoft.hybridcompute/machines"
| extend status     = tostring(properties.status),
         agent      = tostring(properties.agentVersion),
         osName     = tostring(properties.osName),     // "windows" | "linux"
         osVersion  = tostring(properties.osVersion),
         osSku      = tostring(properties.osSku),      // e.g. "Windows Server 2022 Datacenter", "Ubuntu 22.04"
         lastStatusChange = todatetime(properties.lastStatusChange)
| project name, resourceGroup, location, status, agent, osName, osSku, osVersion, lastStatusChange
| order by osName asc, status asc, name asc
```

```kusto
// Which Arc machines are missing key extensions? (per-OS aware)
let machines =
    arg("").resources
    | where type == "microsoft.hybridcompute/machines"
    | extend osName = tolower(tostring(properties.osName))
    | project machine = tolower(id), name, osName;
let exts =
    arg("").resources
    | where type == "microsoft.hybridcompute/machines/extensions"
    | extend machine = tolower(tostring(split(id, "/extensions/")[0]))
    | summarize extensions = make_set(name) by machine;
machines
| join kind=leftouter exts on machine
| extend
    hasAMA            = iff(osName == "windows",
                            extensions has "AzureMonitorWindowsAgent",
                            extensions has "AzureMonitorLinuxAgent"),
    hasMDE            = iff(osName == "windows",
                            extensions has "MDE.Windows",
                            extensions has "MDE.Linux"),
    hasDefender       = iff(osName == "windows",
                            extensions has "AzureSecurityWindowsAgent",
                            extensions has "AzureSecurityLinuxAgent"),
    hasChangeTracking = iff(osName == "windows",
                            extensions has "ChangeTracking-Windows",
                            extensions has "ChangeTracking-Linux"),
    hasGuestConfig    = iff(osName == "windows",
                            extensions has "AzurePolicyforWindows",
                            extensions has "ConfigurationforLinux")
| project name, osName, hasAMA, hasMDE, hasDefender, hasChangeTracking, hasGuestConfig, extensions
| where hasAMA == false or hasMDE == false or hasDefender == false
       or hasChangeTracking == false or hasGuestConfig == false
| order by osName asc, name asc
```

```kusto
// Heartbeat health over the last 24h — Windows + Linux Arc machines
// Category is "Azure Monitor Agent" for AMA; "Direct Agent" only for legacy MMA holdouts.
// ResourceType "machines" comes from microsoft.hybridcompute/machines (works for both OSes).
Heartbeat
| where TimeGenerated > ago(24h)
| where ResourceType == "machines"
       or Category in ("Azure Monitor Agent","Direct Agent")
| summarize lastSeen = max(TimeGenerated),
            beats   = count(),
            os      = any(OSType),       // "Windows" or "Linux"
            osName  = any(OSName),
            agent   = any(Category),
            version = any(Version)
            by Computer
| extend stale = iff(lastSeen < ago(15m), "STALE", "ok")
| order by os asc, stale desc, lastSeen asc
```

---

## 16. Troubleshooting — when something on the Arc machine breaks

This is the playbook for the most common failure: an **extension** (AMA, MDE, ChangeTracking, Defender agent, Update Manager, Guest Config) shows **Provisioning state: Failed** or **Transitioning** for hours. The pattern is the same for every extension — only the directory names differ.

### 16.1 Where to look in the portal first

1. **Azure Arc → Machines → \<server\> → Settings → Extensions**
   - Click the failed extension. The **Status message** at the top is the single most useful field — it almost always quotes the underlying error (download failure, dependency missing, exit code, conflict with another extension).
   - Note the **Type handler version** — extension issues are often fixed by bumping `autoUpgradeMinorVersion: true` or by uninstalling and reinstalling so the latest handler is pulled.
2. **Activity log** on the machine resource — filter to the last 24h, operation `Microsoft.HybridCompute/machines/extensions/write`. You'll see who/what triggered the install and the exact deployment correlation ID.
3. **Resource Health** (left nav of the machine) — tells you if the *agent* itself (not an extension) is the problem (Disconnected / Expired).
4. **Defender for Cloud → Inventory → \<machine\>** — under "Recommendations" it will explicitly call out failed Defender / MDE / AMA installs and usually links straight to the right remediation.

### 16.2 On-box log locations (the ones that actually matter)

The Connected Machine agent and every extension write logs to predictable paths. These are what Microsoft Support will ask for first.

**Windows**

| Component | Path |
|---|---|
| Connected Machine agent (`himds`) | `C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log` |
| Extension manager (decides what to install/upgrade) | `C:\ProgramData\AzureConnectedMachineAgent\Log\gcm.log` |
| Guest Configuration agent | `C:\ProgramData\GuestConfig\arc_policy_logs\gc_agent.log` |
| Per-extension handler logs | `C:\ProgramData\GuestConfig\extension_logs\<ExtensionName>\` |
| AMA (Azure Monitor Agent) | `C:\WindowsAzure\Resources\AMADataStore.<machine>\Tables\` and `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent\<version>\` |
| MDE (`MDE.Windows`) handler | `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.AzureDefenderForServers.MDE.Windows\<version>\` plus on-box MDE: `Get-MpComputerStatus`, `mpcmdrun.exe -getfiles` for full Defender diagnostics |
| Defender for Cloud agent | `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.AzureDefenderForServers.AzureSecurityWindowsAgent\<version>\` |
| Update Manager assessment / install | `C:\ProgramData\GuestConfig\extension_logs\Microsoft.SoftwareUpdateManagement.WindowsOsUpdateExtension\` |

**Linux**

| Component | Path |
|---|---|
| Connected Machine agent | `/var/opt/azcmagent/log/himds.log` |
| Extension manager | `/var/opt/azcmagent/log/gcm.log` |
| `azcmagent` CLI logs | `/var/opt/azcmagent/log/azcmagent.log` |
| Per-extension handler logs | `/var/lib/GuestConfig/extension_logs/<ExtensionName>/` |
| AMA | `/var/opt/microsoft/azuremonitoragent/log/mdsd.*` and `/var/log/azure/Microsoft.Azure.Monitor.AzureMonitorLinuxAgent/` |
| MDE (`MDE.Linux`) handler | `/var/log/azure/Microsoft.Azure.AzureDefenderForServers.MDE.Linux/` plus on-box: `mdatp health`, `sudo mdatp diagnostic create` |
| Defender for Cloud agent | `/var/log/azure/Microsoft.Azure.AzureDefenderForServers.AzureSecurityLinuxAgent/` |
| Guest Configuration | `/var/lib/GuestConfig/arc_policy_logs/gc_agent.log` |
| Update Manager (Linux patch ext) | `/var/log/azure/Microsoft.SoftwareUpdateManagement.LinuxOsUpdateExtension/` |
| systemd journal for the agent | `journalctl -u himdsd -u gcad -u extd --since "1 hour ago"` |

### 16.3 What the logs actually look like (so you know what to grep for)

`himds.log` lines look like this — useful when the agent shows **Disconnected** or token errors:

```
time="2026-05-11T19:42:08Z" level=info  msg="Sending heartbeat" correlationId=2c1f...
time="2026-05-11T19:42:09Z" level=error msg="Failed to acquire MSI token: AADSTS70043: The refresh token has expired" endpoint="login.microsoftonline.com"
time="2026-05-11T19:42:09Z" level=warn  msg="Disconnecting; will retry in 60s"
```

Grep targets: `level=error`, `correlationId=`, `AADSTS`, `proxy`, `certificate`, `endpoint=`.

`gcm.log` (extension manager) — this is the one that tells you *why* an extension never installed:

```
[gcm] INFO  Received goal state: install Microsoft.Azure.Monitor.AzureMonitorWindowsAgent v1.24
[gcm] INFO  Downloading handler package from https://...blob.core.windows.net/...
[gcm] ERROR Failed to download handler: 403 AuthenticationFailed (proxy returned 403)
[gcm] ERROR Handler 'AzureMonitorWindowsAgent' transitioned to state 'Failed' (exit code 51)
```

Per-handler logs (e.g. `extension_logs\AzureMonitorWindowsAgent\CommandExecution.log` or `.../enable.log`) look like:

```
2026/05/11 19:55:01 [Info] Handler is starting enable command
2026/05/11 19:55:03 [Info] Calling: MonAgentLauncher.exe -configFile ...
2026/05/11 19:55:14 [Error] MonAgentLauncher exited with code 4 — invalid DCR association
2026/05/11 19:55:14 [Error] enable command failed; reporting status=error
```

### 16.4 Exit codes and what they usually mean

Extension handlers report a numeric exit code that surfaces in the portal Status message. Cheat sheet:

| Code | Meaning | Typical fix |
|---|---|---|
| `0` | Success | – |
| `1` | Generic failure — read the handler log | Read `enable.log` / `CommandExecution.log` |
| `3` | Handler already running / already installed | Wait, then re-check; if stuck, restart agent |
| `9` | Missing dependency on the OS | Install prereq (e.g., `libssl`, .NET, `python`) |
| `20` | Configuration error in extension settings | Fix DCR association / workspace key / settings JSON |
| `51` | Network / proxy blocking download | Open required FQDNs; check proxy env vars |
| `52` | Disk full or no space in `/var` or `C:\ProgramData` | Free space; AMA needs ≥1 GB free |
| `53` | Conflicting extension (e.g., old MMA + AMA together) | Remove the legacy MMA / OMS agent |
| `100`+ | Handler-specific — check that handler's docs | – |

### 16.5 The 7 fixes that resolve ~90% of Arc extension failures

1. **Restart the agent stack** — this alone fixes most transient `Transitioning`/`Unknown` states:
   ```powershell
   # Windows
   Restart-Service himds, gcarcservice, ExtensionService
   ```
   ```bash
   # Linux
   sudo systemctl restart himdsd gcad extd
   ```
2. **`azcmagent check`** — confirms every required endpoint. A single blocked FQDN (commonly `*.guestconfiguration.azure.com` or `*.his.arc.azure.com`) kills extension delivery.
3. **Update the Connected Machine agent**. Many "extension X failed" issues are actually old `azcmagent`. Target N-2 max.
   ```powershell
   # Windows: re-run the MSI from https://aka.ms/AzureConnectedMachineAgent
   ```
   ```bash
   sudo apt-get update && sudo apt-get install --only-upgrade azcmagent   # Debian/Ubuntu
   sudo dnf upgrade azcmagent                                              # RHEL/Alma/Rocky
   sudo zypper update azcmagent                                            # SLES
   ```
4. **Uninstall and reinstall the extension** from the portal. Forces a fresh handler package download — fixes corrupt-package and "stuck since first deploy" cases.
5. **Disk space**: AMA in particular needs ~1 GB free in `C:\WindowsAzure\Resources` / `/var/opt/microsoft/azuremonitoragent`. A full disk silently breaks every extension.
6. **Time skew**: clock drift >5 min breaks Entra token acquisition. `w32tm /resync` / `chronyc makestep`.
7. **Remove conflicting legacy agents**: the **MMA / OMS agent** must be off before AMA installs cleanly; an old **System Center Endpoint Protection** must be removed before MDE enables in active mode.

### 16.6 Component-specific gotchas

- **AMA**: extension installed but no data in Log Analytics → you forgot the **Data Collection Rule association**. The extension cannot ingest without one.
- **MDE.Windows / MDE.Linux**: handler succeeds but `mdatp health` shows `org_id = null` → Defender for Cloud connector to MDE is not enabled, or the machine onboarded into the *wrong* tenant. Offboard with `MdeClientAnalyzer` / `mdatp config --offboard` and let Defender for Cloud reapply.
- **ChangeTracking**: requires AMA + a DCR with the ChangeTracking data source. Without the DCR it installs cleanly but emits no data.
- **Update Manager / WindowsOsUpdateExtension**: failure with code 20 usually = the machine isn't licensed for Azure Benefits or doesn't have a valid Windows Update source (WSUS pointing at a dead server, no internet on a private box).
- **Guest Configuration (AzurePolicyforWindows / ConfigurationforLinux)**: stuck `Compliant: false` for hours → look in `gc_agent.log`; PowerShell DSC / Inspec module download failed (proxy or AMPLS missing the `guestconfiguration` endpoint).
- **Private Link (AMPLS for Arc)**: if you enabled it after onboarding, the agent keeps using public endpoints until you set `azcmagent config set connection.type private` and restart the service.

### 16.7 Collect everything for a support ticket

When you've tried the above and want to open a case, run the built-in collector — it bundles every log path above into a single zip/tarball:

```powershell
# Windows — produces a zip in the working directory
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" logs
```

```bash
# Linux
sudo azcmagent logs
```

Attach that file plus the **correlation ID** from `gcm.log` to the Azure support request.

### 16.8 Quick KQL for portal-side triage

> **Heartbeat `Category` note (AMA vs MMA):** with **Azure Monitor Agent** the value is `"Azure Monitor Agent"`, not `"Direct Agent"` (that was the legacy MMA/OMS string). To target Arc machines regardless of agent type, filter on `ResourceType == "machines"` (from `microsoft.hybridcompute/machines`). Every query below works for both Windows and Linux Arc machines.

```kusto
// Failed/stuck extensions across all Arc machines — Windows + Linux
arg("").resources
| where type == "microsoft.hybridcompute/machines/extensions"
| extend machine      = tolower(tostring(split(id, "/extensions/")[0])),
         state        = tostring(properties.provisioningState),
         status       = tostring(properties.instanceView.status.message),
         lastModified = todatetime(properties.instanceView.status.time),
         platform     = case(
                            name has_any ("Windows","MDE.Windows","AzurePolicyforWindows"), "Windows",
                            name has_any ("Linux","MDE.Linux","ConfigurationforLinux"),     "Linux",
                            "Unknown")
| where state != "Succeeded"
| project machine, name, platform, state, status, lastModified
| order by platform asc, lastModified desc
```

```kusto
// Arc machines that stopped heart-beating in the last 6h — Windows + Linux
Heartbeat
| where TimeGenerated > ago(24h)
| where ResourceType == "machines"
       or Category in ("Azure Monitor Agent","Direct Agent")
| summarize lastSeen = max(TimeGenerated),
            os      = any(OSType),     // Windows | Linux
            osName  = any(OSName),
            agent   = any(Category)
            by Computer
| where lastSeen < ago(6h)
| order by os asc, lastSeen asc
```

```kusto
// Recent extension write operations (success + failure) with correlation IDs
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue endswith "/extensions/write"
| extend extName = tostring(split(_ResourceId, "/extensions/")[1]),
         platform = case(
            extName has_any ("Windows","MDE.Windows","AzurePolicyforWindows"), "Windows",
            extName has_any ("Linux","MDE.Linux","ConfigurationforLinux"),     "Linux",
            "Unknown")
| project TimeGenerated, Resource, extName, platform, ActivityStatusValue, Caller, CorrelationId, Properties
| order by TimeGenerated desc
```

```kusto
// AMA ingestion sanity — last hour of perf/events split by OS (catches "AMA installed but DCR missing")
union withsource=TableName Perf, Syslog, Event, SecurityEvent
| where TimeGenerated > ago(1h)
| extend Computer = tolower(Computer)
| summarize lastIngest = max(TimeGenerated), rows = count() by Computer, TableName
| order by Computer asc, TableName asc
```

---

## TL;DR ordered checklist per new machine

1. `azcmagent show` / `azcmagent check` — Connected, endpoints OK.
2. Tag it (env, owner, patchgroup).
3. **Licenses → Windows Server**: attest Azure Benefits (Windows only).
4. **Defender for Cloud → Environment settings**: Servers Plan 2 ON, MDVM + MDE + Agentless + FIM + AMA autoprovision ON.
5. **Monitor → DCR**: associate machine to Windows or Linux DCR → workspace.
6. **Insights → Enable** (VM Insights).
7. **Update Manager**: assess + attach maintenance configuration.
8. **Machine Configuration**: assign security baseline initiative.
9. **Extensions**: confirm AMA, MDE, Defender, ChangeTracking, Policy = Succeeded.
10. **Identity**: confirm system-assigned MI; grant only the Azure RBAC the box actually needs.
11. (If SQL) license + Defender for SQL + best-practices assessment.
12. **Sentinel** connectors (if applicable).
13. Alerts: heartbeat-missing, agent-stale, extension-failed, high-sev Defender alerts, overdue updates.
14. Re-run the Resource Graph/KQL queries above weekly until all servers are clean.
