# Post Azure Arc Onboarding — Verification & Best-Practice Checklist

Scope: machines onboarded **manually** (interactive `azcmagent connect` or generated install script) to Azure Arc, mixed Windows Server + Linux, with **Microsoft Entra ID P2** and (assumed) **Defender for Servers P2** available.

The Arc onboarding script only installs and registers the **Connected Machine agent (azcmagent)**. Everything below is what you still have to enable, verify, or wire up *after* the script finishes.

Section order intentionally **mirrors the Azure Arc service blade left-nav** (Overview → Infrastructure → Data services → Operations → Licenses → Additional setup → Migration → Help). Anything that lives outside the Arc blade (Defender for Cloud, Azure Monitor, Sentinel, Update Manager, Alerts, KQL) is grouped at the end under **Part B — Outside the Azure Arc blade**.

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
- `azcmagent check` — all endpoints reachable (especially `*.guestconfiguration.azure.com`, `*.his.arc.azure.com`, `*.waconazure.com`, `download.microsoft.com`; in Gov substitute `.us`).

In the portal: **Azure Arc → Machines → \<server\> → Overview** should show **Status: Connected** and a recent **Last seen** timestamp.

---

# Part A — Inside the Azure Arc service blade

## 1. Overview / All Azure Arc resources — resource hygiene

This is the landing blade. Confirm the basics before drilling into a machine:

| Per-machine blade | What to set / verify |
|---|---|
| **Overview** | Status = Connected, OS detected correctly, correct subscription + resource group. |
| **Tags** | Apply your standard tags (`environment`, `owner`, `costcenter`, `criticality`, `patchgroup`). Many downstream policies and Update Manager schedules target by tag — do this before you wire anything else up. |
| **Properties** | Confirm **Operating system**, **Cloud provider** (will say "Other" / on-prem), **Domain**, **Public key**. |
| **Locks** | Optional `CanNotDelete` lock on production servers so the Arc resource can't be removed accidentally. |
| **Access control (IAM)** | Grant least-privilege roles. Common ones: *Azure Connected Machine Onboarding*, *Azure Connected Machine Resource Administrator*, *Monitoring Reader/Contributor*. Avoid Owner. |
| **Activity log** | Bookmark — first place to look when something changes (extension install, license toggle, RBAC change). |
| **Resource Health** | Tells you if the agent itself is Disconnected / Expired. |

---

## 2. Infrastructure → Machines (per-machine blades, in nav order)

### 2.1 Settings → Connect — connectivity & private networking

- Decide **Public endpoint** vs **Private Link Scope (Azure Arc Private Link Scope)**. If you committed to private, create the scope and associate the machines; the agent will then resolve `*.his.arc.azure.com` (or `.us` in Gov), guest configuration, and extension endpoints over private IPs.
- Configure proxy if you use one:
  ```powershell
  azcmagent config set proxy.url http://proxy:8080
  azcmagent config set proxy.bypass "ArcData,Guestconfig"
  ```
- If you enabled Private Link **after** onboarding, the agent keeps using public endpoints until you set:
  ```powershell
  azcmagent config set connection.type private
  Restart-Service himds, gcarcservice, ExtensionService
  ```

### 2.2 Settings → Identity — system-assigned managed identity

- Every Arc machine automatically gets a **system-assigned managed identity**. Confirm **Object (principal) ID** is present.
- Use that identity (not stored secrets) when scripts on the box need to talk to Azure:
  - Grant scoped roles (e.g., `Key Vault Secrets User` on a specific vault, `Storage Blob Data Reader` on a container).
  - On the box, fetch a token from `http://localhost:40342/metadata/identity/oauth2/token` — Arc's IMDS-equivalent endpoint (different port than Azure VMs).
- Because you have **Entra ID P2**, also enable for the humans who manage the Arc resources:
  - **Privileged Identity Management (PIM)** for any admin role on `Microsoft.HybridCompute/machines/*`.
  - **Conditional Access** covering Azure management sign-ins (the agent itself uses its own MSI and is exempt; the admins are not).
  - **Identity Protection** risk policies for the admin accounts.

### 2.3 Settings → Extensions — the extensions you'll commonly want

Either deploy per-machine here, or (better) via Azure Policy "Deploy if not exists" at the resource-group / subscription scope:

| Extension | Purpose | Win | Linux |
|---|---|:-:|:-:|
| `AzureMonitorWindowsAgent` / `AzureMonitorLinuxAgent` | AMA for logs / metrics | ✓ | ✓ |
| `MDE.Windows` / `MDE.Linux` | Defender for Endpoint | ✓ | ✓ |
| `ChangeTracking-Windows` / `-Linux` | File / registry / software change tracking (AMA-based) | ✓ | ✓ |
| `AzureSecurityWindowsAgent` / `AzureSecurityLinuxAgent` | Defender for Cloud agent | ✓ | ✓ |
| `WindowsAdminCenter` | Browser-based RDP-less admin from the portal | ✓ | – |
| `AzurePolicyforWindows` / `ConfigurationforLinux` | Guest configuration engine | ✓ | ✓ |
| `KeyVaultForWindows` / `KeyVaultForLinux` | Auto-rotate certs from Key Vault | ✓ | ✓ |
| `RunCommandHandlerWindows` / `Linux` | Portal Run Command | ✓ | ✓ |
| `CustomScriptExtension` | Ad-hoc bootstrap scripts | ✓ | ✓ |

Verify each one shows **Provisioning state: Succeeded**. Failed extensions are the #1 source of "Defender thinks the box is unhealthy" tickets — see Section 7 for the troubleshooting playbook.

### 2.4 Operations → Machine Configuration (Guest Configuration)

The Arc equivalent of Azure Policy *inside* the OS. Free for Arc machines under SA or Pay-as-you-go.

- **Policy → Definitions** — assign built-in initiatives that matter:
  - *\[Preview\]: Windows machines should meet requirements for the Azure compute security baseline* (CIS-aligned).
  - *Linux machines should meet requirements for the Azure compute security baseline*.
  - *Configure time zone on Windows machines* (if applicable).
  - *Deploy prerequisites to enable Guest Configuration policies on virtual machines* — required, also covers Arc.
- After ~30–60 min, **Machine Configuration** on the server shows compliance per assignment. Remediate or exempt.

### 2.5 Operations → Inventory & Change Tracking

- Turn both on; they share AMA + a DCR that includes the **ChangeTracking** data source.
- Useful for audit, drift detection after patching, and to feed Sentinel investigation timelines.
- Common gotcha: ChangeTracking extension installs cleanly but emits no data because the DCR has no ChangeTracking data source — see Section 7.

### 2.6 Operations → SSH & Windows Admin Center (no inbound ports)

Big quality-of-life win regardless of plan:

- **Settings → Connect → SSH** (or run `az ssh arc --name <server> --resource-group <rg>`): tunneled SSH/RDP through the Arc agent — no public IP, no VPN.
- **Windows management → Windows Admin Center**: deploy the WAC extension, then manage the server in-browser from the portal.
- Both require the admin to have **Virtual Machine Local User Login** (or Administrator Login) RBAC on the Arc resource.

---

## 3. Data services → SQL Server instances (if applicable)

If any of these servers run SQL Server, the Arc agent auto-discovers instances and registers them as **Arc-enabled SQL Server** resources. Then:

- License each instance (PAYG or BYOL with SA) — same Azure Benefits attestation pattern as Windows Server.
- Enable **Defender for SQL servers on machines** in Defender for Cloud (separate plan toggle from Defender for Servers P2).
- From the **SQL – Azure Arc** resource blade turn on:
  - **Best practices assessment**
  - **Automated backups to Azure Blob**
  - **Microsoft Entra authentication for SQL**

---

## 4. Licenses (Arc service-level blade)

### 4.1 Azure Benefits — Windows Server

- **License status** = Licensed.
- **Activate Azure benefits** checked — this attests Software Assurance / subscription licensing and unlocks:
  - Azure Update Manager at no per-server charge for Arc machines covered by SA.
  - Extended Security Updates (ESU) eligibility for Server 2012 / 2012 R2 (and 2016/2019 when they reach EOS).
  - Azure Policy guest configuration at no charge.
- If a server is **not** under SA, use **Pay-as-you-go with Azure** — but the machine has to be unlicensed (KMS/MAK removed) first.

### 4.2 Extended Security Updates — Windows Server

- For Server 2012 / 2012 R2 boxes, link the machine to an **ESU license** on this blade. Without the link, the WSUS / Update Manager assessment will refuse to surface the ESU-marked patches.

### 4.3 SQL Server licensing & ESU — SQL Server

- License each Arc-enabled SQL Server instance (PAYG or BYOL with SA).
- For end-of-support SQL versions, attach an **ESU - SQL Server** license here so security patches keep flowing.

---

## 5. Additional setup

### 5.1 Azure Arc gateway

- The Arc gateway lets you funnel agent traffic through a small allow-list of FQDNs in tightly-controlled networks (DoD / IL5 / isolated VLANs). Configure it before private link if your firewall team won't accept the wildcard endpoint list.

### 5.2 Private link scopes

- Create an **Azure Arc Private Link Scope (AAMPLS)** in the right region, associate the target subscriptions / resource groups, and link your **Private Endpoint** to a VNet that the on-prem network can route to.
- Switch the agent to private mode (see 2.1).

### 5.3 Service principals

- Used for **at-scale onboarding** (Group Policy / Ansible / SCCM-driven). One SPN with the *Azure Connected Machine Onboarding* role at the target resource-group scope is the minimum-privilege pattern. Rotate its secret on a schedule.

---

## 6. Migration → Savings and readiness (preview)

> **If you do not see this blade**, that is expected in several scenarios. It does **not** indicate a misconfiguration:
> - **Azure Government / USGovDoD (IL5)** — the Migration → Savings and readiness preview is not generally available in sovereign clouds yet. Use Azure Migrate (commercial) tooling, or skip this section entirely.
> - **Subscriptions without the preview feature flag enabled** — register the `Microsoft.Migrate` resource provider on the subscription, and confirm the tenant is opted into the preview.
> - **Missing RBAC** — the signed-in user needs at least `Reader` on the subscription **plus** `Microsoft.Migrate/migrateProjects/read` (typically via the **Migration Contributor** or **Contributor** role).
> - **No Arc machines in scope yet** — the readiness scan only renders the tile once it discovers eligible hybrid machines under the subscription.
>
> If the blade is missing and none of the above apply, it is safe to skip. The same recommendations surface elsewhere: ESU eligibility in **Azure Arc → Licenses**, Defender for Servers Plan 2 status in **Defender for Cloud → Environment settings**, and Update Manager readiness in **Azure Update Manager → Overview**.

- Run the readiness assessment after onboarding a wave; it identifies machines eligible to move to Azure Update Manager, Defender for Servers Plan 2 conversions, and ESU savings opportunities. Output is a CSV plus inline portal recommendations.

---

## 7. Help → Support + troubleshooting

This is the playbook for the most common Arc failure: an **extension** (AMA, MDE, ChangeTracking, Defender agent, Update Manager, Guest Config) shows **Provisioning state: Failed** or **Transitioning** for hours. The pattern is identical for every extension — only the directory names differ.

### 7.1 Where to look in the portal first

1. **Azure Arc → Machines → \<server\> → Settings → Extensions** — click the failed extension. The **Status message** at the top is the single most useful field; it almost always quotes the underlying error.
2. **Activity log** on the machine resource — filter to the last 24h, operation `Microsoft.HybridCompute/machines/extensions/write`. You'll see who/what triggered the install and the deployment correlation ID.
3. **Resource Health** (left nav of the machine) — tells you if the *agent* (not an extension) is Disconnected / Expired.
4. **Defender for Cloud → Inventory → \<machine\>** — under "Recommendations" it will explicitly call out failed Defender / MDE / AMA installs and usually links straight to the right remediation.

### 7.2 Symptom-to-log decision matrix

Use this first. It tells you which log to open for each symptom — both Windows and Linux paths.

| Symptom | What it usually means | Open this log first (Windows) | Open this log first (Linux) |
|---|---|---|---|
| **Portal shows the machine `Disconnected` / `Expired`**, no extension issue | Agent can't reach Azure, MSI token failure, clock skew, proxy / cert problem | `C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log` | `/var/opt/azcmagent/log/himds.log` (or `journalctl -u himdsd`) |
| **Onboarding (`azcmagent connect`) failed** | Bad SPN, wrong tenant/cloud, endpoint blocked | `C:\ProgramData\AzureConnectedMachineAgent\Log\azcmagent.log` | `/var/opt/azcmagent/log/azcmagent.log` |
| **All extensions stuck in `Transitioning` / never installing** | Extension manager can't talk to the goal-state endpoint or download blob | `C:\ProgramData\AzureConnectedMachineAgent\Log\gcm.log` | `/var/opt/azcmagent/log/gcm.log` |
| **A specific extension shows `Failed` or non-zero exit code** | Handler-specific failure (config error, dependency, conflict) | `C:\ProgramData\GuestConfig\extension_logs\<ExtName>\CommandExecution.log` + `enable.log` | `/var/lib/GuestConfig/extension_logs/<ExtName>/` |
| **AMA installed `Succeeded` but no data in Log Analytics** | Missing or misconfigured DCR association | `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent\<ver>\` + `C:\WindowsAzure\Resources\AMADataStore.*\Tables\` | `/var/opt/microsoft/azuremonitoragent/log/mdsd.*` + `/var/log/azure/Microsoft.Azure.Monitor.AzureMonitorLinuxAgent/` |
| **MDE.Windows / MDE.Linux extension `Succeeded` but device not in Defender portal**, or `org_id` is null | MDE onboarding payload missing / wrong tenant / blocked Defender URLs | `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.AzureDefenderForServers.MDE.Windows\<ver>\` + `Get-MpComputerStatus`, `mpcmdrun.exe -getfiles` | `/var/log/azure/Microsoft.Azure.AzureDefenderForServers.MDE.Linux/` + `mdatp health`, `sudo mdatp diagnostic create` |
| **Defender for Cloud agent (`AzureSecurityWindowsAgent` / `Linux`) failing** | Workspace key wrong, proxy auth, Defender plan not enabled at subscription | `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.AzureDefenderForServers.AzureSecurityWindowsAgent\<ver>\` | `/var/log/azure/Microsoft.Azure.AzureDefenderForServers.AzureSecurityLinuxAgent/` |
| **Guest Configuration assignment `Compliant=false` forever** | DSC / Inspec module download failed, agent not reaching `guestconfiguration` endpoint | `C:\ProgramData\GuestConfig\arc_policy_logs\gc_agent.log` + `C:\ProgramData\GuestConfig\Configuration\<assignment>\` | `/var/lib/GuestConfig/arc_policy_logs/gc_agent.log` |
| **Update Manager: no patches detected / scan never completes** | WSUS pointing at a dead server, machine not licensed for Azure Benefits, missing endpoints | `C:\ProgramData\GuestConfig\extension_logs\Microsoft.SoftwareUpdateManagement.WindowsOsUpdateExtension\` | `/var/log/azure/Microsoft.SoftwareUpdateManagement.LinuxOsUpdateExtension/` |
| **ChangeTracking installed but no data** | DCR has no ChangeTracking data source | Handler logs as above + DCR association in Monitor | Same |
| **All agent services restart in a loop** | Disk full, bad cert, time skew | Event Viewer → Application + `himds.log` | `journalctl -u himdsd -u gcad -u extd --since "1 hour ago"` |
| **Confirm whether handler ever saw the install request** | Need correlation ID and goal-state timestamp | `gcm.log` (search the extension name) | `gcm.log` |

> Rule of thumb: **`himds.log` for the agent, `gcm.log` for "did the extension get told to install at all", per-extension `enable.log` / `CommandExecution.log` for "why did the install fail"**.

### 7.3 Full on-box log locations (reference)

**Windows**

| Component | Path |
|---|---|
| Connected Machine agent (`himds`) | `C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log` |
| Extension manager (decides what to install / upgrade) | `C:\ProgramData\AzureConnectedMachineAgent\Log\gcm.log` |
| `azcmagent` CLI logs | `C:\ProgramData\AzureConnectedMachineAgent\Log\azcmagent.log` |
| Guest Configuration agent | `C:\ProgramData\GuestConfig\arc_policy_logs\gc_agent.log` |
| Per-extension handler logs | `C:\ProgramData\GuestConfig\extension_logs\<ExtensionName>\` |
| AMA (Azure Monitor Agent) | `C:\WindowsAzure\Resources\AMADataStore.<machine>\Tables\` and `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.Monitor.AzureMonitorWindowsAgent\<ver>\` |
| MDE (`MDE.Windows`) handler | `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.AzureDefenderForServers.MDE.Windows\<ver>\` plus on-box: `Get-MpComputerStatus`, `mpcmdrun.exe -getfiles` |
| Defender for Cloud agent | `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.AzureDefenderForServers.AzureSecurityWindowsAgent\<ver>\` |
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

### 7.4 What the logs actually look like (so you know what to grep for)

`himds.log` lines — useful when the agent shows **Disconnected** or token errors:

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

Per-handler logs (e.g. `extension_logs\AzureMonitorWindowsAgent\CommandExecution.log` or `.../enable.log`):

```
2026/05/11 19:55:01 [Info] Handler is starting enable command
2026/05/11 19:55:03 [Info] Calling: MonAgentLauncher.exe -configFile ...
2026/05/11 19:55:14 [Error] MonAgentLauncher exited with code 4 — invalid DCR association
2026/05/11 19:55:14 [Error] enable command failed; reporting status=error
```

### 7.5 Exit codes and what they usually mean

Extension handlers report a numeric exit code that surfaces in the portal Status message. Cheat sheet:

| Code | Meaning | Typical fix |
|---|---|---|
| `0` | Success | – |
| `1` | Generic failure — read the handler log | Read `enable.log` / `CommandExecution.log` |
| `3` | Handler already running / already installed | Wait, then re-check; if stuck, restart agent |
| `9` | Missing dependency on the OS | Install prereq (e.g., `libssl`, .NET, `python`) |
| `20` | Configuration error in extension settings | Fix DCR association / workspace key / settings JSON |
| `51` | Network / proxy blocking download | Open required FQDNs; check proxy env vars |
| `52` | Disk full or no space in `/var` or `C:\ProgramData` | Free space; AMA needs >=1 GB free |
| `53` | Conflicting extension (e.g., old MMA + AMA together) | Remove the legacy MMA / OMS agent |
| `100`+ | Handler-specific — check that handler's docs | – |

### 7.6 The 7 fixes that resolve ~90% of Arc extension failures

1. **Restart the agent stack** — this alone fixes most transient `Transitioning` / `Unknown` states:
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

### 7.7 Component-specific gotchas

- **AMA**: extension installed but no data in Log Analytics → you forgot the **Data Collection Rule association**. The extension cannot ingest without one.
- **MDE.Windows / MDE.Linux**: handler succeeds but `mdatp health` shows `org_id = null` → Defender for Cloud connector to MDE is not enabled, or the machine onboarded into the *wrong* tenant. Offboard with `MdeClientAnalyzer` / `mdatp config --offboard` and let Defender for Cloud reapply.
- **ChangeTracking**: requires AMA + a DCR with the ChangeTracking data source. Without the DCR it installs cleanly but emits no data.
- **Update Manager / WindowsOsUpdateExtension**: failure with code 20 usually = the machine isn't licensed for Azure Benefits or doesn't have a valid Windows Update source (WSUS pointing at a dead server, no internet on a private box).
- **Guest Configuration (AzurePolicyforWindows / ConfigurationforLinux)**: stuck `Compliant: false` for hours → look in `gc_agent.log`; PowerShell DSC / Inspec module download failed (proxy or AMPLS missing the `guestconfiguration` endpoint).
- **Private Link (AMPLS for Arc)**: if you enabled it after onboarding, the agent keeps using public endpoints until you set `azcmagent config set connection.type private` and restart the service.

### 7.8 Collect everything for a support ticket

When you've tried the above and want to open a case, run the built-in collector — it bundles every log path above into a single zip / tarball:

```powershell
# Windows — produces a zip in the working directory
& "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" logs
```

```bash
# Linux
sudo azcmagent logs
```

Attach that file plus the **correlation ID** from `gcm.log` to the Azure support request.

---

# Part B — Outside the Azure Arc service blade

Everything below is required to get the **Defender for Servers P2** and operational-monitoring value out of the Arc machines, but the controls live in other services — not in the Arc blade itself.

## 8. Microsoft Defender for Cloud — Defender for Servers Plan 2

This is where most of the P2 value lives, and **none of it gets turned on by the Arc onboarding script**.

1. **Defender for Cloud → Environment settings → \<subscription\> → Defender plans**
   - Turn **Servers** ON, set plan to **Plan 2**.
   - Under the Servers row → **Settings**, verify these are **On**:
     - **Vulnerability assessment for machines** → *Microsoft Defender Vulnerability Management* (the integrated MDVM, not legacy Qualys).
     - **Endpoint protection** (Defender for Endpoint integration / MDE.Windows / MDE.Linux extension auto-deploy).
     - **Agentless scanning for machines** (P2 only — gives you software inventory + secrets scanning without an agent on the disk).
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

## 9. Azure Monitor — AMA + DCRs + VM Insights

The AMA extension can be auto-deployed by Defender, but if you want logs / perf / Sentinel you must explicitly create **Data Collection Rules**.

- **Monitor → Data Collection Rules → + Create**
  - Platform: Windows / Linux (one DCR per platform is cleanest).
  - Resources: pick the Arc machines (they show up alongside Azure VMs).
  - Data sources you'll typically want:
    - Windows Event Logs (Security, System, Application, `Microsoft-Windows-Sysmon/Operational` if you use Sysmon).
    - Performance counters (Processor, Memory, LogicalDisk, Network).
    - Linux Syslog (auth, daemon, kern, syslog at LOG_INFO+).
    - Linux performance.
  - Destination: your Log Analytics workspace.
- On the Arc machine blade: **Monitoring → Insights → Enable** → confirms VM Insights DCR + Dependency agent.
- **Monitoring → Logs** — run `Heartbeat | where Computer == "<server>" | take 5` to confirm ingestion. If empty after 15 min, check the AzureMonitorWindowsAgent / AzureMonitorLinuxAgent extension status under **Settings → Extensions**.

---

## 10. Microsoft Sentinel

- **Sentinel → Data connectors**: enable
  - *Windows Security Events via AMA* (uses the same DCR pattern above). Add the **Windows Firewall** data source to that same DCR so the `Microsoft-Windows-Windows Firewall With Advanced Security/Firewall` and `.../ConnectionSecurity` event logs (and the `MicrosoftWindowsWindowsFirewall` provider) ship into Sentinel alongside Security/System/Application — one DCR, one AMA, one connector.
  - *Microsoft Defender for Cloud* (alerts).
  - *Microsoft Defender XDR* if MDE is connected.
  - *Syslog via AMA* / *Common Event Format via AMA* for Linux.
- Verify analytics rules and workbooks see the new hosts (`Heartbeat`, `SecurityEvent`, `Syslog` tables).

---

## 11. Azure Update Manager

- **Azure Update Manager → Machines** — Arc machines appear automatically once connected.
- For each new box (or via a tag-based dynamic scope):
  - Run **Check for updates** (one-time assessment).
  - Create / attach a **Maintenance configuration** (schedule, reboot setting, classifications, pre/post scripts).
  - For Linux, confirm the package manager (apt/yum/dnf/zypper) is detected on the **Updates** tab.
- Set **Patch orchestration** = *Customer Managed Schedules* via Azure Policy "Configure periodic checking for missing system updates" so assessments run every 24h without you scheduling them.
- Azure Backup for Arc-enabled servers (MARS agent or workload backup for SQL on Arc) is a separate install — not done by the Arc agent.

---

## 12. Monitor → Alerts you should create on day one

In **Monitor → Alerts** (or Defender for Cloud → Workflow automation):

- **Heartbeat missing > 15 min** (Arc machine offline). Use the `Heartbeat` table or Resource Health signal `ConnectedMachine - Disconnected`.
- **Agent version older than N-2** (use Resource Graph + workbook).
- **Defender for Cloud high-severity alerts** on the subscription, routed to a Logic App / Action Group / Sentinel incident.
- **Update Manager — pending security updates > 0 for > 7 days**.
- **Extension provisioning failed** (`Microsoft.HybridCompute/machines/extensions` Activity Log).

---

## 13. Sentinel / Defender XDR — "did I miss anything?" KQL pack

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
// Single arg() call — the LA/Sentinel arg() proxy does not allow joining across two arg() invocations.
//
// IMPORTANT — what "false" actually means here:
//   * hasMDE = false  =>  the Arc auto-deploy extension MDE.Windows / MDE.Linux is NOT present.
//                         It does NOT mean MDE is missing. MDE may be onboarded directly via
//                         WindowsDefenderATPOnboardingScript.cmd, GPO, Intune/MEM, MECM, or built-in
//                         Server 2019+. Use the DeviceInfo cross-check query below to verify.
//   * hasDefenderForCloudExt = false  =>  the legacy AzureSecurity*Agent extension is not deployed.
//                         This is EXPECTED on modern Defender for Servers Plan 2 setups that use
//                         AMA + agentless scanning instead of the legacy agent. Don't treat as a fail.
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
    hasAMA                   = iff(osName == "windows",
                                   extensions has "AzureMonitorWindowsAgent",
                                   extensions has "AzureMonitorLinuxAgent"),
    hasMDEExt                = iff(osName == "windows",
                                   extensions has "MDE.Windows",
                                   extensions has "MDE.Linux"),
    hasDefenderForCloudExt   = iff(osName == "windows",
                                   extensions has "AzureSecurityWindowsAgent",
                                   extensions has "AzureSecurityLinuxAgent"),
    hasChangeTracking        = iff(osName == "windows",
                                   extensions has "ChangeTracking-Windows",
                                   extensions has "ChangeTracking-Linux"),
    hasGuestConfig           = iff(osName == "windows",
                                   extensions has "AzurePolicyforWindows",
                                   extensions has "ConfigurationforLinux")
// Only the truly-required extensions in the filter. Defender-for-Cloud-Agent is legacy/optional under P2.
| where hasAMA == false or hasChangeTracking == false or hasGuestConfig == false
| project machineName, osName, hasAMA, hasMDEExt, hasDefenderForCloudExt, hasChangeTracking, hasGuestConfig, extensions
| order by osName asc, machineName asc
```

```kusto
// Real MDE coverage — cross-check Arc inventory against Defender XDR DeviceInfo
// Use this when the query above shows hasMDEExt=false but you believe MDE is onboarded
// via GPO / Intune / MECM / direct script / built-in Server 2019+.
// Requires the M365 Defender connector enabled in Sentinel (DeviceInfo table available).
let arcMachines =
    arg("").resources
    | where type == "microsoft.hybridcompute/machines"
    | extend osName = tolower(tostring(properties.osName)),
             arcName = tolower(name)
    | project arcName, osName, arcId = tolower(id);
let mdeDevices =
    DeviceInfo
    | where Timestamp > ago(7d)
    | summarize arg_max(Timestamp, *) by DeviceName
    | extend deviceNameLower = tolower(DeviceName)
    | project deviceNameLower, OnboardingStatus, OSPlatform, DeviceId,
              MachineGroup, mdeLastSeen = Timestamp;
arcMachines
| join kind=leftouter mdeDevices on $left.arcName == $right.deviceNameLower
| extend mdeOnboarded = (OnboardingStatus == "Onboarded")
| project arcName, osName, mdeOnboarded, OnboardingStatus, mdeLastSeen, DeviceId, MachineGroup
| order by mdeOnboarded asc, arcName asc
```

> If `mdeOnboarded = false` *and* `OnboardingStatus` is blank, MDE genuinely isn't reporting for that host. If `mdeOnboarded = true` but the earlier query shows `hasMDEExt = false`, the device is onboarded outside Arc auto-deploy — that's fine, it just means Defender for Cloud P2 didn't push the extension because something else got there first.

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
            os      = any(OSType),
            osName  = any(OSName),
            agent   = any(Category),
            version = any(Version)
            by Computer
| extend stale = iff(lastSeen < ago(15m), "STALE", "ok")
| order by os asc, stale desc, lastSeen asc
```

```kusto
// Extensions that are not fully healthy — covers provisioning failures AND runtime warnings/errors
// 0 rows = clean fleet. To sanity-check the filter, see the health-distribution query below.
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

```kusto
// Extension health distribution across the fleet — sanity check for the query above.
// Healthy result: a single row "Succeeded / Information" matching your total extension count.
arg("").resources
| where type == "microsoft.hybridcompute/machines/extensions"
| extend state       = tostring(properties.provisioningState),
         statusLevel = tostring(properties.instanceView.status.level)
| summarize count() by state, statusLevel
| order by state asc
```

```kusto
// Recent extension write operations (success + failure) with correlation IDs
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
3. **Arc Licenses → Azure Benefits — Windows Server**: attest (Windows only); link ESU if 2012 / 2012 R2.
4. **Arc machine → Settings → Connect**: confirm public vs Private Link, proxy settings.
5. **Arc machine → Settings → Identity**: system-assigned MI present; grant only scoped RBAC.
6. **Arc machine → Settings → Extensions**: confirm AMA, MDE, Defender, ChangeTracking, Policy = Succeeded.
7. **Arc machine → Operations → Machine Configuration**: assign security baseline initiative.
8. (If SQL) **Data services → SQL Server instances**: license + Defender for SQL + best-practices assessment.
9. **Defender for Cloud → Environment settings**: Servers Plan 2 ON, MDVM + MDE + Agentless + FIM + AMA autoprovision ON.
10. **Monitor → DCR**: associate machine to Windows or Linux DCR → workspace.
11. **Insights → Enable** (VM Insights).
12. **Sentinel** connectors enabled.
13. **Update Manager**: assess + attach maintenance configuration.
14. Alerts: heartbeat-missing, agent-stale, extension-failed, high-sev Defender alerts, overdue updates.
15. Re-run the Sentinel/XDR KQL pack weekly until all servers are clean.
