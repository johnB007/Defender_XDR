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

## 2. Licensing — Windows Server only (the blade in your screenshot)

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

## 6. Microsoft Sentinel (if you use it)

- **Sentinel → Data connectors**: enable
  - *Windows Security Events via AMA* (uses the same DCR pattern above).
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

Run these in **Azure Resource Graph Explorer** or Logs:

```kusto
// Arc machines and their current agent + status
resources
| where type == "microsoft.hybridcompute/machines"
| extend status = properties.status, agent = properties.agentVersion, os = properties.osName
| project name, resourceGroup, location, status, agent, os, lastStatusChange = properties.lastStatusChange
| order by status asc, name asc
```

```kusto
// Which Arc machines are missing key extensions?
resources
| where type == "microsoft.hybridcompute/machines"
| project machine = id, name
| join kind=leftouter (
    resources
    | where type == "microsoft.hybridcompute/machines/extensions"
    | extend machine = tostring(split(id, "/extensions/")[0])
    | summarize extensions = make_set(name) by machine
) on machine
| extend hasAMA      = extensions has_any ("AzureMonitorWindowsAgent","AzureMonitorLinuxAgent"),
         hasMDE      = extensions has_any ("MDE.Windows","MDE.Linux"),
         hasDefender = extensions has_any ("AzureSecurityWindowsAgent","AzureSecurityLinuxAgent")
| project name, hasAMA, hasMDE, hasDefender, extensions
| where hasAMA == false or hasMDE == false or hasDefender == false
```

```kusto
// Heartbeat health over the last 24h
Heartbeat
| where TimeGenerated > ago(24h)
| summarize lastSeen = max(TimeGenerated), beats = count() by Computer, ResourceType
| extend stale = iff(lastSeen < ago(15m), "STALE", "ok")
| order by stale desc, lastSeen asc
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
