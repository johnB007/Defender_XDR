# MDE Windows Server Deployment Guide for IL5 (On-Prem and Azure VMs)

**Document Type:** Step-by-Step Deployment Guide  \
**Environment:** DoD only (IL5 / USGovDoD)  \
**Scope:** On-prem Windows Servers and Azure-hosted Windows VMs

---

## HOW TO USE THIS GUIDE

This guide provides **complete step-by-step instructions** for deploying Microsoft Defender for Endpoint (MDE) on Windows Servers in DoD environments while migrating from Trellix.
Use the steps in the order shown below and validate each phase before proceeding.
---

## TABLE OF CONTENTS

1. **Introduction** - Overview and deployment approach
2. **Prerequisites** - Licensing, network, and access requirements
3. **Pre-Flight Checklist** - Validate readiness before deployment
4. **Phase A: Deploy MDE in EDR Block Mode** - Step-by-step deployment alongside Trellix
5. **Phase A: Validation** - Verify Phase A success before proceeding
6. **Phase B: Transition MDAV to Active Mode** - Switch from Trellix to Microsoft Defender Antivirus as primary AV
7. **Phase B: Validation** - Verify Phase B success
8. **Post-Deployment Configuration** - Optional features and monitoring
9. **Troubleshooting** - Common issues and resolutions
10. **Technical Reference** - Registry settings, endpoints, and documentation links
11. **Handoff Notes (Field Gotchas)** - Common migration pitfalls and extra checks

---

## 1. INTRODUCTION

### Overview

This guide enables migration from Trellix to Microsoft Defender for Endpoint (MDE) on Windows Servers in DoD (IL5/USGovDoD) environments using a **two-phase approach**:

* **Phase A:** Deploy MDE in EDR Block mode alongside Trellix (coexistence)
* **Phase B:** Transition MDAV to Active mode and disable Trellix

 **CRITICAL CONSTRAINT - Tamper Protection:**  
Once Tamper Protection is enabled and MDAV switches to Active mode (Phase B), it **CANNOT** be switched back to Phase A (EDR Block mode) on platform version 4.18.2208.0+. Phase B is a **one-way transition**. Ensure thorough testing before broad deployment.

---

## 2. PREREQUISITES

### 2.1 Network Requirements &nbsp;&nbsp;&nbsp;&nbsp;<span style="color:#0078D4; font-size:0.85em;"> **Verification:** |&nbsp; [Pre-Req Connectivity Check](https://github.com/johnB007/Defender_XDR/blob/main/Microsoft%20Defender%20for%20Endpoint/Defender_for_Servers/MDE_ARC_Pre_Req.md)</span>

#### DoD MDE Endpoints (Streamlined Connectivity - Preview)

 **Preview Status:** Streamlined connectivity is in PREVIEW for US Government. Fully patch Windows Servers before onboarding.

**Applies to:** Windows Server 2019/2022/2025 and Windows Server 2016/2012 R2 with modern unified solution  
**Legacy/MMA:** If any 2012 R2/2016 servers remain on legacy/MMA, also allow standard connectivity list

**Important:** Streamlined connectivity reduces MDE service endpoints but does NOT eliminate dependencies for portal access, onboarding, identity, Live Response, and certificate validation.

 **CRITICAL - Commercial (.com/.net) Endpoints Required for DoD:**  
The following `.com`/`.net` endpoints are **REQUIRED** by Microsoft even for IL5 DoD environments and **CANNOT** be substituted with `.us`/`.mil` equivalents:
* **Certificate Revocation/Validation** (`crl.microsoft.com`, `ctldl.windowsupdate.com`, `www.microsoft.com/pkiops/*`, `www.microsoft.com/pki/certs`) - Required by Windows OS for SSL/TLS certificate trust validation
* **Live Response** (`*.wns.windows.com`, `login.live.com`, `login.microsoftonline.com`) - Required for Live Response functionality

**Minimum Required Endpoints (Core MDE Functionality):**

| Service | FQDN/URL | Port | Direction | Required | Notes |
|---------|----------|------|-----------|----------|-------|
| MDE Streamlined | `*.endpoint.security.microsoft.us` | `443/TCP` | Outbound | Yes | Consolidated Defender for Endpoint services for US Gov (Preview). |
| SmartScreen (DoD) | `unitedstates2.ss.wd.microsoft.us` | `443/TCP` | Outbound | Yes | Required for Network Protection and URL indicators. |
| MDE Config (DoD) | `https://config.ecs.dod.teams.microsoft.us/config/v1` | `443/TCP` | Outbound | Yes | Internal configuration management endpoint. |
| MDE Portal (DoD) | `https://*.securitycenter.microsoft.us` | `443/TCP` | Outbound | Yes | DoD Defender portal access URL. |
| Entra Sign-in (Gov) | `login.microsoftonline.us` | `443/TCP` | Outbound | Yes | US Gov identity endpoint. |
| Certificate Revocation | `crl.microsoft.com/pki/crl/*` | `80/TCP` | Outbound | Yes | Certificate trust validation. |
| Certificate Revocation | `ctldl.windowsupdate.com` | `80/TCP` | Outbound | Yes | Untrusted certificate list updates. |
| Certificate Revocation | `www.microsoft.com/pkiops/*` | `80/TCP` | Outbound | Yes | Certificate validation dependency. |
| Certificate Revocation | `http://www.microsoft.com/pki/certs` | `80/TCP` | Outbound | Yes | Certificate validation dependency. |

**Additional Endpoints Required for Live Response:**

| Service | FQDN/URL | Port | Direction | Required | Notes |
|---------|----------|------|-----------|----------|-------|
| Live Response (WNS) | `*.wns.windows.com` | `443/TCP` | Outbound | Optional | Windows Push Notification Services - Required only if using Live Response. |
| Live Response Auth | `login.live.com` | `443/TCP` | Outbound | Optional | Required only if using Live Response. |
| Entra Sign-in (Common) | `login.microsoftonline.com` | `443/TCP` | Outbound | Optional | Required only if using Live Response. |

If Defender updates are not managed internally (WSUS/ConfigMgr/FileShare), allow the Microsoft Update security intelligence endpoints listed in the [standard connectivity documentation](https://learn.microsoft.com/defender-endpoint/standard-device-connectivity-urls-gov).

#### Azure VM Additional Endpoints (DoD)

Use this section when the same guide is used for native Azure VMs (Defender for Servers integration) in addition to on-prem servers.

**Microsoft Learn references:**
* Defender for Endpoint for US Government customers: https://learn.microsoft.com/defender-endpoint/gov#required-connectivity-settings
* Microsoft Defender for Endpoint streamlined connectivity URLs for US government environments: https://learn.microsoft.com/defender-endpoint/streamlined-device-connectivity-urls-gov
* Microsoft Defender for Endpoint standard connectivity URLs for US government: https://learn.microsoft.com/defender-endpoint/standard-device-connectivity-urls-gov
* Enable Defender for Endpoint integration for Azure VMs: https://learn.microsoft.com/azure/defender-for-cloud/enable-defender-for-endpoint

| Service | FQDN/URL | Port | Direction | Required | Notes |
|---------|----------|------|-----------|----------|-------|
| MDE Onboarding Package (DoD) | `https://onboardingpckgsusgvprd.blob.core.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Required to retrieve onboarding package content from Defender portal workflows. Source: Defender for Endpoint for US Government customers. |
| Defender Portal Dependencies | `https://*.microsoftonline-p.com` | `443/TCP` | Outbound | Yes | Required for Microsoft Defender portal authentication/content dependencies in Gov clouds. Source: Defender for Endpoint streamlined connectivity URLs for US government environments. |
| Defender Portal Dependencies | `https://secure.aadcdn.microsoftonline-p.com` | `443/TCP` | Outbound | Yes | Required for Defender portal sign-in/static auth assets. Source: Defender for Endpoint streamlined connectivity URLs for US government environments. |
| Defender Portal Dependencies | `https://static2.sharepointonline.com` | `443/TCP` | Outbound | Yes | Required for Defender portal static dependency loading. Source: Defender for Endpoint streamlined connectivity URLs for US government environments. |
| Defender Portal Storage Dependency | `*.blob.core.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Required by Defender portal and onboarding package/storage flows. Source: Defender for Endpoint for US Government customers. |
| Defender Telemetry | `events.data.microsoft.com` | `443/TCP` | Outbound | Conditional | Required in standard connectivity mode for Connected User Experiences/Telemetry channel. Source: Defender for Endpoint standard connectivity URLs for US government. |
| MAPS Cloud Protection (DoD) | `unitedstates2.cp.wd.microsoft.us` | `443/TCP` | Outbound | Conditional | Required for Defender Antivirus cloud-delivered protection in standard connectivity mode. Source: Defender for Endpoint standard connectivity URLs for US government. |

**Connectivity Mode Note:**
* If you use streamlined connectivity, keep the streamlined DoD URL set as baseline.
* If you use standard connectivity (or require cloud-delivered protection/telemetry paths), include the standard DoD endpoints above.

---

#### Azure Arc Endpoints (Arc-enabled servers and multicloud/hybrid paths)

| Service | FQDN/URL | Port | Direction | Required | Notes |
|---------|----------|------|-----------|----------|-------|
| Arc ARM (Gov) | `management.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Required to connect/disconnect Arc machine resource. |
| Arc Identity (Gov) | `login.microsoftonline.us` | `443/TCP` | Outbound | Yes | Entra auth for Arc. |
| Arc Identity (Gov) | `pasff.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Entra identity dependency for Arc. |
| Arc Metadata/HIS (Gov) | `*.his.arc.azure.us` | `443/TCP` | Outbound | Yes | Arc hybrid identity and metadata service. |
| Arc Guest Config (Gov) | `*.guestconfiguration.azure.us` | `443/TCP` | Outbound | Yes | Extension and guest configuration management. |
| Arc Extension Packages | `*.blob.core.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Arc extension package source. |

#### Firewall Allow-List:

**Action:** Configure firewall to allow:

1. All outbound HTTPS (TCP 443) to every FQDN in the MDE endpoints table
2. All outbound HTTP (TCP 80) to certificate revocation URLs
3. All outbound HTTPS (TCP 443) to every FQDN in the Azure Arc endpoints table
4. (Optional) Microsoft Update endpoints if NOT using WSUS/ConfigMgr/FileShare for updates

#### Connectivity Validation

* ☐ **Firewall rules configured** for all MDE endpoints (above)
* ☐ **Firewall rules configured** for all Azure Arc endpoints (above, if using Defender for Servers Plan 2)
* ☐ **Proxy configuration tested** (if applicable)

* ☐ **Run MDE Connectivity Analyzer** on each server type to verify all endpoints are accessible
  * Available from MDE Portal settings or Azure Arc guest configuration
  * Verify all critical endpoints return successful connectivity

---

### 2.2 Onboarding Gate (before running MDE / Arc onboarding)

> Run the items below immediately before initiating onboarding. After the host is onboarded, continue with **Section 3** for post-onboarding validation.

* ☐ **Tamper Protection state confirmed BEFORE onboarding.** Tamper Protection must be **OFF / not enforced** at first onboarding so MDAV lands cleanly in passive mode and the 3rd-party AV uninstall is not blocked later.
  ```powershell
  Get-MpComputerStatus | Select-Object IsTamperProtected, AMRunningMode
  ```
  Expected pre-onboard: `IsTamperProtected = False`, `AMRunningMode = Passive` (after `md4ws.msi` install) or `Not running` (before).

* ☐ **Tamper Protection enablement is deferred** until after each wave reaches Phase B (MDAV Active). See *CRITICAL CONSTRAINT, Tamper Protection* in Section 1: Phase B is a **one-way transition** on platform 4.18.2208.0+.

* ☐ **Onboarding executed** via Defender for Cloud P2 to the MDE.Windows / MDE.Linux Arc extension (no manual onboarding script needed when Arc + P2 is in place).

* ☐ **Verify host appears in the Microsoft Defender portal (DoD / IL5):** `https://security.apps.mil` within 15 minutes; last-seen within 24 hours before moving to Section 3.

---

## 3. System Configuration & Policy Validation

**Complete this validation before starting any deployment:**

### 3.1 System & Configuration &nbsp;&nbsp;&nbsp;&nbsp;<span style="color:#0078D4; font-size:0.85em;"> **Validation:**

#### Third-Party EPP Configuration

* ☐ **Third-Party EPP Exceptions**: Configure HBSS/Trellix/Tanium to exclude Microsoft Defender processes
  * Download the MDE connectivity URL list from Microsoft Learn (US Gov): `https://learn.microsoft.com/defender-endpoint/standard-device-connectivity-urls-gov`
  * Review Microsoft Defender Processes tab
  * Ensure all required Microsoft Defender binaries are excluded from third-party EPP scanning
  * Without these exclusions, conflicts will occur during Phase A coexistence (EDR Block mode)

#### GPO Deployment

* ☐ **Deploy MDE Configuration GPOs** (from DoD HBSS Divestment folder):
  * MDE – Configurations GPO - Computer
  * MDE – MDAV Trellix Exclusions GPO - Computer
  * MDE – MDAV Tanium Exclusions GPO - Computer (if applicable)
  * MDE – Device Control - Computer
  
  **Verify GPO applied:**
  ```powershell
  gpresult /scope:computer /h C:\gpreport.html
  # Verify MDE and exclusion GPOs appear in Applied Group Policy Objects
  ```

* ☐ **Modify MDE – Configurations GPO settings:**
  * Modify proxy settings if applicable (Set to Not Configured if not using proxy)
  * Modify telemetry settings: Configure Connected User Experiences and Telemetry (Set to Not Configured if not using proxy)
  * For Server 2012 R2, 2016, and 2019: MDAV will be in Passive Mode until Trellix is removed. Update GPP after Trellix uninstall to delete the registry entry.
  * Update organization-specific contact information in Windows Security Enterprise Customizations

* ☐ **Attack Surface Reduction (ASR) Rules** (configured in MDE – Configurations GPO):
  * Review configured rules; keep higher impact rules in audit mode initially
  * Recommended audit period: 30-60 days before enabling block enforcement

* ☐ **Deploy Current STIGs** for all target servers: Windows Server 2012 R2, 2016, 2019, 2022, 2025 (as applicable), plus Microsoft Defender Antivirus and Windows Firewall STIGs

* ☐ **Review Advanced Settings in MDE Portal** with the Federal MDE Pursuit Team before broad onboarding:
  * Create device groups for customer before onboarding
  * Review automation rules and alert thresholds
  * Verify ASR rule audit data collection is configured

#### Platform Version, Updates & Service Status

* ☐ **Windows Defender feature check** (Server 2016 and 2019+):
  ```powershell
  Get-WindowsFeature -name Windows-Defender
  Add-WindowsFeature -name Windows-Defender -includeallsubfeature
  ```

* ☐ **Windows Defender service present and running**
  ```powershell
  Get-Service -Name WinDefend
  Start-Service -Name WinDefend
  Set-Service -Name WinDefend -StartupType Automatic
  ```

* ☐ **Verify Windows Defender components are current:**
  ```powershell
  Get-MpComputerStatus | Select-Object AMProductVersion
  Get-MpComputerStatus | Select-Object AMEngineVersion
  Get-MpComputerStatus | Select-Object AntivirusSignatureVersion, AntivirusSignatureLastUpdated
  ```

* ☐ **Deploy Required Updates (Apply in sequence):**
  1. **Security Intelligence Update (SIU)** - Target all Windows Servers
     * Download: `http://aka.ms/siu64` or KB2267602
  2. **Platform Update (KB4052623)** - Target all Windows Servers
  3. **Sense EDR Update (KB5005292)** - Target only Windows Server 2012 R2 and 2016 with Unified agent
  
  **Action:** Update via Windows Update/WSUS if versions are outdated. Reboot after each update before proceeding.
  
  * Verify updates applied:
    ```powershell
    Get-MpComputerStatus | Select-Object AMProductVersion, AMEngineVersion, AntivirusSignatureVersion
    ```

* ☐ **Consolidated install order (WS2012 R2 / WS2016)** — run in this exact sequence, then reboot:

  ```powershell
  # 1. Install & start the Defender feature (skip on WS2019/2022 — built-in)
  Add-WindowsFeature -Name Windows-Defender -IncludeAllSubFeature
  Set-Service -Name WinDefend -StartupType Automatic
  Start-Service -Name WinDefend
  ```

  2. Apply **KB4052623** (MDAV Platform Update)
  3. Apply **KB5005292** (MDE EDR Sensor Update — WS2012 R2 / WS2016 only)
  4. **Reboot the server** before running validation or `md4ws.msi`.

  > Reboot is required so `WinDefend` and `Sense` reload with the updated platform binaries. Skipping the reboot is the most common cause of stale `AMProductVersion` and Sense not registering.

### 3.2 Policy & Registry Validation

**Review and validate policy settings that may have disabled Windows Defender for third-party EPP/EDR.**

#### Registry & Policy Configuration

* ☐ **Verify Defender disablement policies are NOT present**
  * `DisableAntiSpyware`, `DisableRealtimeMonitoring`, and `DisableBehaviorMonitoring` should be absent
  * Group Policy: Computer Configuration → Administrative Templates → Windows Components → Microsoft Defender Antivirus → Turn off Microsoft Defender Antivirus = "Not Configured"

* ☐ **Run Group Policy Report**
  ```powershell
  gpresult /H C:\gpreport.html
  ```

#### Group Policy Review - Common Defender Disablement Policies

**Review these common Group Policy settings that may have disabled Windows Defender for third-party EDR/AV:**

| GPO Setting | Path | Impact | Action |
|-------------|------|--------|--------|
| **Turn off Windows Defender Antivirus** | `Computer Configuration → Policies → Windows Defender → Real-time Protection` | Disables MDAV entirely | Must be removed or set to "Not Configured" |
| **Turn off Windows Defender Firewall** | `Computer Configuration → Policies → Windows Defender Firewall` | Disables Defender Firewall | Review if needed for Phase A/B |
| **Disable periodic scanning** | `Computer Configuration → Policies → Windows Defender → Scan` | Disables signature updates | Must be removed for Phase A/B |
| **Disable real-time monitoring** | `Computer Configuration → Policies → Windows Defender → Real-time Protection` | Disables real-time scanning | Must be removed for Phase A/B |
| **Disable behavior monitoring** | `Computer Configuration → Policies → Windows Defender → Real-time Protection` | Disables behavioral detection | Must be removed for EDR Block/MDAV Active mode |
| **Allow antivirus to be disabled** | `Computer Configuration → Policies → Windows Defender → Real-time Protection` | Permits disabling MDAV | Verify setting to prevent accidental disable |

**Action Required:**

* ☐ Review Group Policy Editor: `gpedit.msc` (or GPMC if domain-joined)
  ```powershell
  # Open Group Policy Editor
  gpedit.msc
  # Navigate to: Computer Configuration → Administrative Templates → Windows Components → Windows Defender
  ```
* ☐ Check `Computer Configuration → Administrative Templates → Windows Components → Windows Defender`
* ☐ Verify no policies are forcing Defender OFF
* ☐ If domain-joined, check domain GPOs as well (using GPMC)
  ```powershell
  # Generate Active Directory Group Policy report
  gpresult /scope:computer /h C:\gpreport_domain.html
  # Review for conflicting Windows Defender policies
  ```
* ☐ Document any Defender-disabling policies that must be modified before Phase A

**Important:** Do NOT disable Windows Defender Firewall if it's the primary firewall protection. Only disable if third-party firewall solution is managing network protection.

### 3.3 Exclusions Configuration

* ☐ Trellix exclusions configured for MDAV/MDE binaries

* ☐ MDAV exclusions ready to apply for Trellix binaries

### 3.4 Pre-Flight Summary

* ☐ **All critical checks passed?**
  * All registry validations successful
  * All GPO deployments verified applied
  * All updates installed and verified
  * All firewall rules configured
  * All endpoint connectivity tests successful
  * All exclusions configured
  * All STIGs deployed

---

## 11. Field Gocthas from Previous Deployments

Use this section as a final go/no-go check before broad deployment.

### Common Gotchas to Validate

* ☐ **TLS trust chain is complete**
  * Confirm required root/intermediate CAs are present in the local computer trust stores.
  * Missing trust anchors can cause onboarding, portal sign-in, and update failures even when DNS/TCP checks pass.

* ☐ **CRL/OCSP checks pass**
  * Validate certificate revocation reachability (CRL/OCSP) from each server subnet.
  * If these are blocked, TLS validation failures may appear as intermittent connectivity issues.

* ☐ **Proxy inspection is not breaking Defender traffic**
  * If SSL inspection is enabled, verify Defender endpoints are excluded where required.
  * Confirm the proxy does not rewrite certificates for critical Defender service URLs.

* ☐ **Third-party EDR self-protection/tamper controls are planned**
  * Confirm approved maintenance-window procedure for Trellix policy relaxation or uninstall sequence.
  * Ensure rollback owner and escalation path are documented before cutover.

* ☐ **Mutual exclusions are verified both ways**
  * Validate Trellix exclusions for Defender binaries.
  * Validate Defender exclusions for Trellix binaries during coexistence window.

* ☐ **Defender policy conflicts are source-traced**
  * Capture GPO name and link path for any setting forcing Defender off.
  * Do not proceed until conflicting domain/local policies are remediated.

* ☐ **Service baseline is healthy before onboarding**
  * `WinDefend` and `Sense` services running; platform/engine/signatures current
  * Passive Mode registry entries present for Server 2012 R2, 2016, and 2019 (transition to Active Mode after Trellix removal)

* ☐ **MDE Portal Advanced Settings are reviewed and aligned**
  * Device groups created; automation/remediation rules set; ASR audit data collecting

* ☐ **Onboarding timing expectations are communicated**
  * Define expected time for device appearance and health status in the Defender portal
  * Document who to contact if portal registration exceeds SLA

* ☐ **Pilot exit criteria are explicit**
  * No app-impact regressions observed.
  * Detection telemetry present and stable.
  * CPU/memory utilization within agreed bounds.

* ☐ **Post-cutover drift checks are scheduled**
  * Weekly review for stale signatures, offboarded devices, broken telemetry, and policy drift.

