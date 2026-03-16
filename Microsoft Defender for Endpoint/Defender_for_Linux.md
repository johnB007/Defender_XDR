# MDE Linux Server Deployment Guide for IL5 (On-Prem and Azure VMs) NOT FINAL

**Document Type:** Step-by-Step Deployment Guide  \
**Environment:** DoD only (IL5 / USGovDoD)  \
**Scope:** On-prem Linux Servers and Azure-hosted Linux VMs

---

## HOW TO USE THIS GUIDE

This guide provides **complete step-by-step instructions** for deploying Microsoft Defender for Endpoint (MDE) on Linux Servers in DoD environments. MDE for Linux provides endpoint detection and response (EDR), threat protection, and vulnerability management for RHEL, CentOS, Ubuntu, SLES, and other supported Linux distributions.

Use the steps in the order shown below and validate each phase before proceeding.

---

## TABLE OF CONTENTS

1. **Introduction** - Overview and deployment approach
2. **Prerequisites** - Licensing, network, and access requirements
3. **Supported Operating Systems & Distributions** - Compatibility matrix
4. **Pre-Flight Checklist** - Validate readiness before deployment
5. **Phase A: Deploy MDE Agent** - Step-by-step installation
6. **Phase A: Validation** - Verify Phase A success before proceeding
7. **Post-Deployment Configuration** - Optional features and hardening
8. **Monitoring & Telemetry** - Log analysis and health checks
9. **Troubleshooting** - Common issues and resolutions
10. **Technical Reference** - Service management, registry settings, endpoints, and documentation links
11. **Handoff Notes (Field Gotchas)** - Common deployment pitfalls and extra checks

---

## 1. INTRODUCTION

### Overview

This guide enables deployment of Microsoft Defender for Endpoint (MDE) on Linux Servers in DoD (IL5/USGovDoD) environments using **streamlined deployment approach**:

* **Phase A:** Deploy MDE agent with all protective features enabled
* **Validation:** Verify connectivity, telemetry, and EDR functionality
* **Post-Deployment:** Configure advanced features, tune detection baselines, and integrate with SIEM/SOC

**Key Capabilities:**

* **Endpoint Detection & Response (EDR):** Real-time behavioral analysis and threat hunting
* **Antimalware Protection:** Signature and behavior-based malware detection
* **Vulnerability Management:** Asset inventory and CVE scoring via Defender for Cloud integration
* **Web Protection:** URL filtering and network-based threat blocking
* **Threat & Vulnerability Management (TVM):** Built-in inventory and risk scoring

**CRITICAL CONSTRAINT - Agent Version:**  
MDE for Linux requires agent version **101.88.xx** or newer for DoD IL5 environments. Earlier versions lack critical fixes for government endpoint connectivity and telemetry routing. Ensure all servers are updated to current agent versions before proceeding to Phase A.

**Note:** This guide covers Linux servers only (on-prem and Azure-hosted). For Windows server deployments, refer to the Windows Server Deployment Guide.

---

## 2. PREREQUISITES

### 2.1 Licensing Requirements

* ☐ **Microsoft Defender for Endpoint Plan 2 (or Defender for Server Plan 2)** 
  * Includes: EDR, antimalware, TVM, and RBAC features
  * Verify licensing is assigned in Microsoft 365 Security Center (DoD/GCC-High)

* ☐ **For Azure-hosted VMs:** Verify Defender for Servers Plan 2 is enabled in Azure Defender/Defender for Cloud
  * Go to Azure Defender → Environment Settings → select subscription → Defender Plans
  * Ensure "Defender for Servers Plan 2" is toggled ON

---

### 2.2 Network Requirements

#### DoD MDE Endpoints (Streamlined Connectivity - Preview)

**Preview Status:** Streamlined connectivity is in PREVIEW for US Government. Ensure all Linux servers are fully patched with latest kernel and package updates before onboarding.

**Applies to:** All supported Linux distributions (RHEL 7.2+, CentOS 7.2+, Ubuntu 16.04+, SLES 12+)

**Important:** Streamlined connectivity reduces MDE service endpoints but does NOT eliminate dependencies for portal access, onboarding, identity, Live Response, and certificate validation.

**CRITICAL - Commercial (.com/.net) Endpoints Required for DoD:**  
The following `.com`/`.net` endpoints are **REQUIRED** by Microsoft even for IL5 DoD environments and **CANNOT** be substituted with `.us`/`.mil` equivalents:
* **Certificate Revocation/Validation** (`crl.microsoft.com`, `ctldl.windowsupdate.com`, `www.microsoft.com/pkiops/*`, `www.microsoft.com/pki/certs`) - Required by Linux OS for SSL/TLS certificate trust validation
* **Live Response** (`*.wns.windows.com`, `login.live.com`, `login.microsoftonline.com`) - Required for Live Response and remote investigation functionality

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

#### Azure VM Additional Endpoints (DoD)

Use this section when deploying to native Azure VMs (Defender for Servers integration) in addition to on-prem Linux servers.

**Microsoft Learn references:**
* Defender for Endpoint for US Government customers: https://learn.microsoft.com/defender-endpoint/gov
* Microsoft Defender for Endpoint streamlined connectivity URLs for US government environments: https://learn.microsoft.com/defender-endpoint/streamlined-device-connectivity-urls-gov
* Microsoft Defender for Endpoint standard connectivity URLs for US government: https://learn.microsoft.com/defender-endpoint/standard-device-connectivity-urls-gov
* Enable Defender for Endpoint integration for Azure VMs: https://learn.microsoft.com/azure/defender-for-cloud/enable-defender-for-endpoint
* MDE for Linux deployment: https://learn.microsoft.com/defender-endpoint/linux-install-manually

| Service | FQDN/URL | Port | Direction | Required | Notes |
|---------|----------|------|-----------|----------|-------|
| MDE Onboarding Package (DoD) | `https://onboardingpckgsusgvprd.blob.core.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Required to retrieve onboarding package content from Defender portal workflows. |
| Defender Portal Dependencies | `https://*.microsoftonline-p.com` | `443/TCP` | Outbound | Yes | Required for Microsoft Defender portal authentication/content dependencies in Gov clouds. |
| Defender Portal Dependencies | `https://secure.aadcdn.microsoftonline-p.com` | `443/TCP` | Outbound | Yes | Required for Defender portal sign-in/static auth assets. |
| Defender Portal Dependencies | `https://static2.sharepointonline.com` | `443/TCP` | Outbound | Yes | Required for Defender portal static dependency loading. |
| Defender Portal Storage Dependency | `*.blob.core.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Required by Defender portal and onboarding package/storage flows. |
| Defender Telemetry | `events.data.microsoft.com` | `443/TCP` | Outbound | Conditional | Required in standard connectivity mode for Connected User Experiences/Telemetry channel. |
| MAPS Cloud Protection (DoD) | `unitedstates2.cp.wd.microsoft.us` | `443/TCP` | Outbound | Conditional | Required for Defender Antivirus cloud-delivered protection in standard connectivity mode. |

#### Azure Arc Endpoints (Arc-enabled servers and multicloud/hybrid paths)

| Service | FQDN/URL | Port | Direction | Required | Notes |
|---------|----------|------|-----------|----------|-------|
| Arc ARM (Gov) | `management.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Required to connect/disconnect Arc machine resource. |
| Arc Identity (Gov) | `login.microsoftonline.us` | `443/TCP` | Outbound | Yes | Entra auth for Arc. |
| Arc Identity (Gov) | `pasff.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Entra identity dependency for Arc. |
| Arc Metadata/HIS (Gov) | `*.his.arc.azure.us` | `443/TCP` | Outbound | Yes | Arc hybrid identity and metadata service. |
| Arc Guest Config (Gov) | `*.guestconfiguration.azure.us` | `443/TCP` | Outbound | Yes | Extension and guest configuration management. |
| Arc Extension Packages | `*.blob.core.usgovcloudapi.net` | `443/TCP` | Outbound | Yes | Arc extension package source. |

#### Firewall Allow-List

**Action:** Configure firewall/security groups to allow:

1. All outbound HTTPS (TCP 443) to every FQDN in the MDE endpoints table
2. All outbound HTTP (TCP 80) to certificate revocation URLs
3. All outbound HTTPS (TCP 443) to every FQDN in the Azure Arc endpoints table (if applicable)

**Example iptables rules (Linux):**
```bash
# Allow MDE core endpoints
sudo iptables -A OUTPUT -p tcp -d *.endpoint.security.microsoft.us -m tcp --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p tcp -d *.securitycenter.microsoft.us -m tcp --dport 443 -j ACCEPT

# Allow certificate validation
sudo iptables -A OUTPUT -p tcp -d crl.microsoft.com -m tcp --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p tcp -d www.microsoft.com -m tcp --dport 80 -j ACCEPT

# For Azure VMs: save rules with firewalld or iptables-persistent
sudo systemctl restart firewalld  # if using firewalld
sudo iptables-save | sudo tee /etc/iptables/rules.v4  # if using iptables
```

**Example AWS Security Group (Azure VMs equivalent):**
```
Egress Rule:
  Protocol: TCP
  Port Range: 443
  Destination: CIDR or Security Group for MDE endpoints
  
Egress Rule:
  Protocol: TCP
  Port Range: 80
  Destination: CIDR or Security Group for Certificate CRL endpoints
```

#### Connectivity Validation

* ☐ **Firewall rules configured** for all MDE endpoints (above)
* ☐ **Firewall rules configured** for all Azure Arc endpoints (above, if using Defender for Servers Plan 2)
* ☐ **Proxy configuration tested** (if applicable)

* ☐ **Run connectivity test from a test Linux server:**
  ```bash
  # Test core MDE endpoint connectivity
  curl -v https://x.cp.wd.microsoft.us/  # Should return 200 or 403
  
  # Test Entra auth endpoint
  curl -v https://login.microsoftonline.us/
  
  # Test certificate revocation
  curl -v http://crl.microsoft.com/pki/crl/
  
  # All tests should return HTTP status (not connection timeout/refused)
  ```

* ☐ **Verify firewall/proxy does not block or inspect MDE traffic**
  * Confirm no SSL inspection on MDE endpoints
  * Test from multiple subnets if segmented

---

## 3. SUPPORTED OPERATING SYSTEMS & DISTRIBUTIONS

### Compatibility Matrix

**Supported Distributions:**

| Distribution | Versions | Kernel | Status | Notes |
|--------------|----------|--------|--------|-------|
| **Red Hat Enterprise Linux (RHEL)** | 7.2, 7.x, 8.x, 9.x | 3.10.0 + | Supported | Primary platform for IL5 DoD deployments |
| **CentOS** | 7.2, 7.x, 8.x | 3.10.0 + | Supported | RHEL-compatible; use RHEL guidance |
| **Ubuntu** | 16.04 LTS, 18.04 LTS, 20.04 LTS, 22.04 LTS | 4.4 + | Supported | Popular in commercial/hybrid environments |
| **SLES (SUSE Linux Enterprise)** | 12, 15 | 4.4 + | Supported | Enterprise support via SUSE |
| **Debian** | 9, 10, 11 | 4.4 + | Supported | Community distribution; less common in DoD |
| **Oracle Linux** | 7.x, 8.x, 9.x | 4.4 + | Supported | RHEL-compatible; certification pending |
| **Amazon Linux 2** | All versions | 5.4 + | Supported | AWS-specific distribution |

### Unsupported Configurations

* ❌ **Kernel versions < 3.10.0** (RHEL/CentOS 6 or older)
* ❌ **Custom/unsigned kernels** without CONFIG_HAVE_EBPF_JIT enabled
* ❌ **Containerized deployments** (Docker/Kubernetes agents require separate deployment model)
* ❌ **WSL (Windows Subsystem for Linux)** - Use Windows Defender for Windows hosts

---

## 4. System Configuration & Policy Validation

**Complete this validation before starting any deployment:**

### 4.1 System & Configuration Validation

#### Kernel & System Requirements

* ☐ **Verify kernel version supports MDE**
  ```bash
  uname -r
  # Must be >= 3.10.0 for RHEL/CentOS, >= 4.4 for Ubuntu/SLES
  ```

* ☐ **Verify kernel has eBPF support (required for EDR)**
  ```bash
  grep CONFIG_HAVE_EBPF_JIT /boot/config-$(uname -r)
  # Should show: CONFIG_HAVE_EBPF_JIT=y
  ```

* ☐ **Verify systemd is available** (required for agent management)
  ```bash
  systemctl --version
  ps --no-headers -o comm 1 | grep -q systemd
  # Should return systemd (not init)
  ```

* ☐ **Check available disk space** (minimum 10 GB recommended for agent + threat intelligence)
  ```bash
  df -h /
  df -h /var
  # Both should have >= 10 GB available
  ```

* ☐ **Verify network connectivity is healthy**
  ```bash
  ip route show
  ping 8.8.8.8
  # Should have active routes and external connectivity
  ```

#### Package Manager & Repository Configuration

* ☐ **Verify yum/apt is functional** (for installing MDE dependencies)
  ```bash
  # RHEL/CentOS:
  sudo yum check
  sudo yum update -y
  
  # Ubuntu/Debian:
  sudo apt update
  sudo apt upgrade -y
  ```

* ☐ **Install required dependencies** (MDE requires curl, openssl, etc.)
  ```bash
  # RHEL/CentOS:
  sudo yum install -y curl openssl ca-certificates
  
  # Ubuntu/Debian:
  sudo apt install -y curl openssl ca-certificates
  ```

* ☐ **Verify SSL/TLS certificate store is current**
  ```bash
  # Check default CA bundle location
  ls -la /etc/ssl/certs/ca-bundle.crt  # RHEL/CentOS
  ls -la /etc/ssl/certs/ca-certificates.crt  # Ubuntu/Debian
  
  # Update if outdated
  sudo update-ca-certificates
  ```

#### Third-Party Security Software Conflicts

* ☐ **Identify installed security tools** (may conflict with MDE)
  ```bash
  rpm -qa | grep -i security  # RHEL/CentOS
  dpkg -l | grep -i security  # Ubuntu
  
  # Document: SELinux, AppArmor, third-party EDR, IDS/IPS, firewalls
  ```

* ☐ **SELinux Configuration** (if present, may require tuning for MDE)
  ```bash
  getenforce
  # If enforcing: may need custom policies for MDE binaries
  # Recommendation: document baseline for troubleshooting
  ```

* ☐ **AppArmor Configuration** (if present on Ubuntu/SLES)
  ```bash
  sudo aa-status
  # If running: may need MDE-specific AppArmor profile
  # MDE provides default profile; install or review before deploying
  ```

* ☐ **Firewall & iptables Configuration**
  ```bash
  sudo systemctl status firewalld  # RHEL/CentOS
  sudo ufw status  # Ubuntu
  
  # Document rules that may block MDE outbound traffic
  ```

### 4.2 Pre-Flight Summary

* ☐ **All critical checks passed?**
  * Kernel version >= 3.10 (RHEL) or >= 4.4 (Ubuntu/SLES)
  * eBPF support enabled in kernel
  * systemd is active init system
  * >= 10 GB disk space available in / and /var
  * Network connectivity verified
  * Package managers functional
  * SSL/TLS certificate store current
  * Third-party security tools identified and compatibility assessed
  * SELinux/AppArmor baseline documented
  * Firewall rules allow outbound to MDE endpoints

---

## 5. PHASE A: DEPLOY MDE AGENT

### 5.1 Obtain Onboarding Package

**Action:** Download the onboarding package from Microsoft Defender portal:

1. Go to https://securitycenter.microsoft.us (DoD)
2. Select **Settings** → **Endpoints** → **Onboarding**
3. In the dropdown, select **Linux Server**
4. Download the **onboarding package** (typically `mdatp-onboarding-linux.py` or similar)

**Alternative (for Azure Arc-enabled servers):**
* Onboarding package can be obtained via Azure Arc guest configuration extension
* Download package manually from Defender portal (recommended for on-prem)

### 5.2 Installation via Package Manager

**Recommended method for enterprise deployments (yum/apt):**

#### RHEL/CentOS Installation

```bash
# 1. Add Microsoft Repository for MDE Linux packages
curl https://raw.githubusercontent.com/microsoft/mdatp-xplat-linux/master/linux_installation_scripts/install_mde_linux.sh | bash
# or manually:
sudo bash -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/config/rhel/7/prod/ rhel main" > /etc/yum.repos.d/microsoft.repo'

# 2. Import Microsoft GPG key
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# 3. Install MDE agent
sudo yum install mdatp
# or 
sudo yum install mdatp-latest

# 4. Enable and start the agent
sudo systemctl enable mdatp
sudo systemctl start mdatp

# 5. Verify installation
mdatp health
sudo systemctl status mdatp
```

#### Ubuntu/Debian Installation

```bash
# 1. Add Microsoft Repository for MDE Linux packages
curl https://raw.githubusercontent.com/microsoft/mdatp-xplat-linux/master/linux_installation_scripts/install_mde_linux.sh | bash

# 2. Import Microsoft GPG key
sudo wget -q https://packages.microsoft.com/keys/microsoft.asc -O /etc/apt/trusted.gpg.d/microsoft.asc

# 3. Update package lists
sudo apt update

# 4. Install MDE agent
sudo apt install mdatp
# or for latest version:
sudo apt install mdatp-latest

# 5. Enable and start the agent
sudo systemctl enable mdatp
sudo systemctl start mdatp

# 6. Verify installation
mdatp health
sudo systemctl status mdatp
```

#### SLES Installation

```bash
# 1. Add Microsoft Repository
sudo zypper addrepo https://packages.microsoft.com/config/sles/12/prod \
  microsoft-prod

# 2. Import GPG key
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# 3. Install MDE agent
sudo zypper install mdatp
sudo zypper install mdatp-latest

# 4. Enable and start
sudo systemctl enable mdatp
sudo systemctl start mdatp

# 5. Verify
mdatp health
```

### 5.3 Onboarding to Defender for Endpoint Portal

**Action:** Run onboarding script after agent installation:

```bash
# 1. Make onboarding script executable
chmod +x ~/mdatp-onboarding-linux.py

# 2. Run onboarding (with root/sudo)
sudo ~/mdatp-onboarding-linux.py

# 3. Verify onboarding succeeded
sudo mdatp health --field org_id
# Should return organization ID (not empty)

# 4. Check telemetry status
sudo mdatp telemetry
# Should show: 'Telemetry status': Enabled
```

### 5.4 Verify Agent Installation & Connectivity

**Wait 5-10 minutes after onboarding, then validate:**

```bash
# Check MDE service status
sudo systemctl status mdatp
# Should show: Active (running)

# Check agent version
mdatp -v
# Should return version >= 101.88.xx

# Verify device health
sudo mdatp health
# Look for:
#   'service_running': true
#   'real_time_protection_enabled': true
#   'automatic_sample_submission_consent': true
#   'org_id': [not empty]

# Check threat intelligence update status
sudo mdatp threat-intelligence-definition-status
# Should show recent update timestamp

# Monitor telemetry
sudo tail -f /var/log/microsoft/mdatp/audit.log
# Should show telemetry events being sent (wait 10+ seconds)

# Test EDR capability (safe detection)
# Note: Only test in lab/approved environment!
# Create benign test file that triggers EICAR detection (safe):
# echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.txt
# Should be detected within 10 seconds in portal
```

---

## 6. PHASE A: VALIDATION

### 6.1 Connectivity Validation

**Verify the server has established connection to Defender portal:**

```bash
# Check for Defender portal communication
sudo ss -tlnp | grep mdatp
# Should show listening ports for MDE services

# Monitor for outbound connections to Defender
sudo ss -tonp | grep mdatp
# Should show established (ESTAB) connections

# Check DNS resolution of MDE endpoints
nslookup x.cp.wd.microsoft.us
# Should resolve to IP address (not NXDOMAIN)

# Verify certificate validation chain
curl -v https://x.cp.wd.microsoft.us/
# Should return 200, 403, or 401 (not certificate error)
```

### 6.2 Telemetry & Detection Validation

**Verify the server is sending security telemetry:**

```bash
# Check for recent log entries in audit.log
sudo tail -100 /var/log/microsoft/mdatp/audit.log | grep -i "telemetry\|detection\|event"

# Monitor live telemetry stream
sudo mdatp diagnostic create --output /tmp/diag.zip

# Check for file scanning activity
sudo mdatp threat-intelligence-definition-status

# Verify real-time protection is enabled
sudo mdatp config real-time-protection --get
# Should return: on

# Verify file quarantine capability
# Note: Only in test/lab environments
# Create test detection file and confirm quarantine
```

### 6.3 Portal Verification

**Check Defender portal for device registration:**

1. Go to https://securitycenter.microsoft.us (DoD)
2. Select **Devices & Vulnerabilities** → **Device Inventory**
3. Search for hostname of newly onboarded Linux server
4. Verify device status shows **Active** or **Healthy**
5. Confirm **Defender version** is visible and current
6. Check for **Sensor Health Status** = **Active**

**Portal Health Indicators:**
* ☐ Device appears in inventory within 5-10 minutes
* ☐ Device health status shows "Active" (not "Inactive" or "Impaired")
* ☐ Defender version shows as current (101.88.xx+)
* ☐ Sensor health status shows "Active"
* ☐ First telemetry events appear within 10-15 minutes of installation

### 6.4 Common Validation Issues & Troubleshooting

**Issue: Device does not appear in portal**
```bash
# Verify agent is running
sudo systemctl status mdatp

# Check agent was onboarded successfully
sudo mdatp health --field org_id

# Review agent logs for errors
sudo mdatp diagnostic create --output /tmp/diag.zip
unzip -l /tmp/diag.zip | grep -i error
```

**Issue: Sensor health status = "Impaired"**
```bash
# Verify real-time protection is enabled
sudo mdatp config real-time-protection --get

# Check for policy enforcement issues
sudo mdatp config real-time-protection --set=on

# Verify threat intelligence is up-to-date
sudo mdatp threat-intelligence-definition-status
```

**Issue: Telemetry not being sent**
```bash
# Verify telemetry is enabled
sudo mdatp telemetry

# Check network connectivity to Defender endpoints
curl -v https://x.cp.wd.microsoft.us/

# Review firewall/proxy logs for blocked connections
```

### 6.5 Validation Pass/Fail Criteria

**Phase A Validation PASS when:**
* ✅ Device appears in Defender portal within 5-10 minutes
* ✅ Device health status = "Active"
* ✅ Sensor health status = "Active"
* ✅ Threat intelligence definition timestamp is recent (< 24 hours)
* ✅ Telemetry events are visible in portal
* ✅ Agent logs show no critical errors

**Phase A Validation FAIL if:**
* ❌ Device does not appear in portal after 15 minutes
* ❌ Device health status = "Inactive" or "Impaired"
* ❌ Sensor health status = "Offline" or "Impaired"
* ❌ Threat intelligence definitions are stale (> 7 days old)
* ❌ Telemetry is not reaching portal
* ❌ Agent logs show critical connectivity/authentication errors

**Action if validation fails:**
1. Troubleshoot using diagnostic steps above
2. Verify firewall/proxy allows all MDE endpoints
3. Confirm SSL/TLS certificate validation is working
4. Review agent error logs in diagnostic output
5. If unresolved, escalate to Microsoft Support with diagnostic.zip

---

## 7. POST-DEPLOYMENT CONFIGURATION

### 7.1 Threat & Vulnerability Management (TVM)

**Enable asset inventory and CVE scoring:**

* ☐ **Verify TVM is enabled in Defender portal**
  * Go to **Settings** → **Endpoints** → **Advanced Features**
  * Toggle **Threat and Vulnerability Management** = ON

* ☐ **Verify software inventory is collecting**
  ```bash
  # Check for inventory telemetry in audit logs
  sudo tail -f /var/log/microsoft/mdatp/audit.log | grep -i "inventory\|software"
  
  # May take 24-48 hours for full inventory to appear in portal
  ```

### 7.2 EDR Investigation Capabilities

**Configure settings for threat hunting and incident response:**

* ☐ **Enable Live Response** (if needed for SOC investigations)
  * Go to **Settings** → **Endpoints** → **Advanced Features**
  * Toggle **Live Response** = ON

* ☐ **Configure Automated Investigation & Response (AIR)**
  * Go to **Settings** → **Endpoints** → **Automated Investigation & Response**
  * Adjust automation level (Recommended: "Semi-automated" for IT review)
  * Review automation rules for file quarantine policies

### 7.3 File Exclusions & Whitelist Configuration

**Configure exclusions for operational stability (if needed):**

```bash
# Example: Exclude application logs directory from real-time scanning
sudo mdatp exclusion folder --add /var/log/application

# Example: Exclude specific file types
sudo mdatp exclusion file-extension --add .log

# Example: Exclude process
sudo mdatp exclusion process-name --add mysqld

# List current exclusions
sudo mdatp exclusion folder --list
sudo mdatp exclusion file-extension --list
sudo mdatp exclusion process-name --list
```

**Important:** Only add exclusions if operational impact is observed (high CPU/disk I/O). MDE is optimized to minimize performance impact on exclusion-free configurations.

### 7.4 Custom Alert Rules & Indicators

**Create organization-specific detection rules (if desired):**

1. Go to **Settings** → **Endpoints** → **Indicators**
2. Click **Add Indicator**
3. Define threat indicators:
   * File hash (MD5, SHA1, SHA256)
   * IP address
   * URL
   * Domain
4. Set action (Alert, Alert and Block, or Allow)
5. Assign to device groups

**Example use cases:**
* Internal tools/scripts that trigger false positives → Add as allowed
* Known-bad hashes from threat intel feeds → Add as blocked
* Suspicious internal domains → Add as monitored

### 7.5 Device Groups & RBAC Configuration

**Organize devices for scalable management:**

1. Go to **Settings** → **Endpoints** → **Device Groups**
2. Create device groups by:
   * Operating system (Linux, Windows, macOS)
   * Department or business unit
   * Risk tier
   * Geographic location

3. Assign RBAC roles for team access:
   * Go to **Settings** → **Users & Roles**
   * Create custom roles with least-privilege scopes

---

## 8. MONITORING & TELEMETRY

### 8.1 MDE Agent Logs & Diagnostics

**Location of key MDE log files:**

```bash
# Audit log (events, telemetry, detections)
/var/log/microsoft/mdatp/audit.log

# Installation log
/var/log/microsoft/mdatp/install.log

# Threat intelligence updates
/var/log/microsoft/mdatp/diag.log

# Performance/resource usage
/var/log/microsoft/mdatp/perf.log

# Real-time protection events
/var/log/microsoft/mdatp/real-time-protection.log
```

**Monitor agent health continuously:**

```bash
# Watch audit log for new events (real-time)
sudo tail -f /var/log/microsoft/mdatp/audit.log

# Search for detections/alerts
sudo grep -i "detection\|malware\|threat" /var/log/microsoft/mdatp/audit.log

# Search for errors
sudo grep -i "error\|failed\|critical" /var/log/microsoft/mdatp/audit.log

# Check agent CPU/memory usage
ps aux | grep mdatp

# Monitor network connections
sudo ss -tonp | grep mdatp
```

### 8.2 SIEM Integration (Optional)

**Forward MDE telemetry to SIEM for centralized monitoring:**

#### Syslog Export (via rsyslog)

```bash
# 1. Forward MDE audit log to rsyslog
echo "/var/log/microsoft/mdatp/audit.log" | sudo tee -a /etc/rsyslog.d/mdatp.conf
echo "*.info @@siem-server:514" | sudo tee -a /etc/rsyslog.d/mdatp.conf

# 2. Restart rsyslog
sudo systemctl restart rsyslog
```

#### Log Collection via Azure Log Analytics (if available)

**Azure VMs:** Use Azure Monitor agent to send MDE logs to Log Analytics workspace:

```bash
# 1. Install Azure Monitor agent (if not already installed)
wget https://aka.ms/dependencyagentlinux -O InstallDependencyAgent-Linux64.bin
sudo sh InstallDependencyAgent-Linux64.bin -s

# 2. Configure MDE log collection in Log Analytics workspace
# Done via Azure portal → Log Analytics → Data Collection Rules
# Specify /var/log/microsoft/mdatp/audit.log as collection path
```

### 8.3 Alert & Incident Response Workflow

**Set up notifications for critical detections:**

1. Go to **Settings** → **Endpoints** → **Email Notifications**
2. Configure email alerts for:
   * High/Critical severity detections
   * Policy violations
   * Sensor health alerts
3. Assign recipients (SOC team, CISO, etc.)

**Incident Response Workflow:**
1. Alert triggered in Defender portal
2. Email notification sent to SOC team
3. SOC investigates using:
   * **Device timeline** (process/file activity)
   * **Live Response** (if enabled - remote shell execution)
   * **Advanced Hunting** (KQL queries across event data)
4. Containment action taken (isolate device, block hash, etc.)
5. Remediation and recovery

---

## 9. TROUBLESHOOTING

### 9.1 Agent Installation Issues

**Issue: Agent fails to install or update**

```bash
# Verify repository is accessible
sudo yum repolist  # RHEL/CentOS
sudo apt-cache policy mdatp  # Ubuntu

# Try manual installation
sudo yum install -y mdatp-latest

# Check for dependency conflicts
sudo yum check-update

# If persistent, install from downloaded package
# Download from: https://packages.microsoft.com/config/rhel/[version]/prod/
```

**Issue: Systemd service fails to start**

```bash
# Check service status and error message
sudo systemctl status mdatp -l

# View detailed service logs
sudo journalctl -u mdatp -n 100

# Verify required dependencies
sudo rpm -qa | grep openssl
sudo rpm -qa | grep curl

# Try manual restart
sudo systemctl restart mdatp

# If still failing, check for kernel issues
dmesg | tail -50 | grep -i mdatp
```

### 9.2 Connectivity Issues

**Issue: Agent cannot reach Defender endpoints**

```bash
# Verify DNS resolution
nslookup x.cp.wd.microsoft.us
dig x.cp.wd.microsoft.us

# Test HTTPS connectivity
curl -v https://x.cp.wd.microsoft.us/
# Should return 200/403/401, not certificate/timeout error

# Check if firewall/proxy is blocking
sudo iptables -L -n | grep DROP

# Test with curl through proxy (if applicable)
curl -v --proxy [proxy-server]:[port] https://x.cp.wd.microsoft.us/

# Monitor network connections
sudo tcpdump -i eth0 -n 'host x.cp.wd.microsoft.us and port 443'
```

**Issue: Certificate validation errors**

```bash
# Verify SSL/TLS certificate store
ls -la /etc/ssl/certs/ca-certificates.crt  # Ubuntu/Debian
ls -la /etc/ssl/certs/ca-bundle.crt  # RHEL/CentOS

# Update certificate store
sudo update-ca-certificates  # Ubuntu/Debian
sudo update-ca-trust  # RHEL/CentOS

# Test certificate validation
openssl s_client -connect x.cp.wd.microsoft.us:443 \
  -CAfile /etc/ssl/certs/ca-bundle.crt
```

### 9.3 Performance & Resource Issues

**Issue: High CPU or memory usage from MDE processes**

```bash
# Check resource usage
ps aux | grep mdatp
top -p $(pgrep -f mdatp)

# MDE typical resource usage:
# CPU: < 5% (can spike to 10-20% during scans)
# Memory: 100-300 MB (can peak during large file scanning)

# If excessive, check for:
# 1. Full threat intelligence update
sudo mdatp threat-intelligence-definition-status

# 2. Excessive logging/debugging (disable if not needed)
sudo mdatp config log-level --set=info

# 3. Exclude high-I/O directories (carefully, only if necessary)
sudo mdatp exclusion folder --add /var/log/high-volume-app
```

**Issue: Disk space consumed by MDE**

```bash
# Check MDE directory sizes
du -sh /var/opt/microsoft/mdatp/
du -sh /var/log/microsoft/mdatp/

# Clean old audit logs (keep recent)
sudo find /var/log/microsoft/mdatp/ -name "audit.log.*" -mtime +30 -delete

# Rotate logs with logrotate (if not already configured)
cat /etc/logrotate.d/microsoft-mdatp
```

### 9.4 Detection & Quarantine Issues

**Issue: Legitimate files are being detected/quarantined**

```bash
# Restore quarantined file
sudo mdatp threat quarantine list
# Review suspicious files

# Add file to exclusion if confirmed benign
sudo mdatp exclusion file-hash --add [SHA256_HASH]

# Report false positive to Microsoft
# Via Defender portal: Settings → Feedback → Submit sample
```

**Issue: Detections not appearing in portal**

```bash
# Verify telemetry is being sent
sudo mdatp telemetry

# Check audit log for detection events
sudo grep -i "detection\|malware" /var/log/microsoft/mdatp/audit.log

# Enable verbose logging to diagnose
sudo mdatp config log-level --set=debug
# Reproduce detection scenario
sudo mdatp config log-level --set=info  # reset to normal

# Check portal Threat Intelligence Definition age
sudo mdatp threat-intelligence-definition-status
# Should be < 24 hours old
```

### 9.5 Diagnostic Collection

**Collect full diagnostic data for Microsoft Support:**

```bash
# Generate diagnostic bundle
sudo mdatp diagnostic create --output /tmp/mde-diag.zip

# Include system information
sudo tar -czf /tmp/system-info.tar.gz \
  /var/log/microsoft/mdatp/ \
  /etc/os-release \
  <(systemctl status mdatp) \
  <(mdatp -v) \
  <(mdatp health)

# Share with Microsoft Support
ls -lh /tmp/mde-diag.zip /tmp/system-info.tar.gz
```

---

## 10. TECHNICAL REFERENCE

### 10.1 MDE Agent Management Commands

**Common mdatp CLI commands:**

```bash
# Health & Status
sudo mdatp health                                    # Overall agent health
sudo mdatp -v                                        # Agent version
sudo mdatp health --field org_id                     # Organization ID
sudo mdatp health --field deployment_id             # Deployment ID

# Configuration
sudo mdatp config real-time-protection --get        # Check RTP status
sudo mdatp config real-time-protection --set=on    # Enable RTP
sudo mdatp config real-time-protection --set=off   # Disable RTP
sudo mdatp config cloud-service-enabled --get       # Check cloud service
sudo mdatp config cloud-service-enabled --set=on   # Enable cloud service

# Threat Intelligence
sudo mdatp threat-intelligence-definition-status    # Definition version
sudo mdatp scan quick                               # Quick scan
sudo mdatp scan full                                # Full system scan

# Exclusions
sudo mdatp exclusion folder --add /path              # Exclude folder
sudo mdatp exclusion folder --list                   # List folder exclusions
sudo mdatp exclusion file-extension --add .log       # Exclude file type
sudo mdatp exclusion process-name --add mysqld      # Exclude process

# Quarantine & Threat Management
sudo mdatp threat quarantine list                    # List quarantined files
sudo mdatp threat quarantine restore [SHA256]       # Restore quarantined file

# Telemetry & Logging
sudo mdatp telemetry                                # Telemetry status
sudo mdatp config log-level --get                   # Current log level
sudo mdatp config log-level --set=debug             # Set log level
```

### 10.2 Service Management

**Systemd service commands:**

```bash
# Service status
sudo systemctl status mdatp
sudo systemctl is-active mdatp
sudo systemctl is-enabled mdatp

# Start/Stop/Restart
sudo systemctl start mdatp
sudo systemctl stop mdatp
sudo systemctl restart mdatp

# Enable/Disable automatic startup
sudo systemctl enable mdatp
sudo systemctl disable mdatp

# View service logs
sudo journalctl -u mdatp -n 100
sudo journalctl -u mdatp -f                         # Follow logs
```

### 10.3 Firewall Configuration Examples

**iptables example (persistent):**

```bash
# Allow MDE endpoints
sudo iptables -I OUTPUT -p tcp -d *.endpoint.security.microsoft.us -m tcp --dport 443 -j ACCEPT

# Save rules (requires iptables-persistent)
sudo iptables-save | sudo tee /etc/iptables/rules.v4
sudo ip6tables-save | sudo tee /etc/iptables/rules.v6

# Enable iptables-persistent on boot
sudo systemctl enable iptables-persistent
```

**firewalld example:**

```bash
# Add service zone for MDE
sudo firewall-cmd --permanent --new-service mdatp
sudo firewall-cmd --permanent --service mdatp --add-port=443/tcp
sudo firewall-cmd --permanent --add-service mdatp --zone=public

# Apply rules
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

**ufw example (Ubuntu):**

```bash
# Allow outbound to MDE endpoints
sudo ufw allow out to any port 443
sudo ufw allow out http

# Verify
sudo ufw show added
```

### 10.4 Microsoft Learn References

* **MDE for Linux Overview:** https://learn.microsoft.com/defender-endpoint/linux-overview
* **MDE for Linux Installation:** https://learn.microsoft.com/defender-endpoint/linux-install-manually
* **MDE for Linux Configuration:** https://learn.microsoft.com/defender-endpoint/linux-preferences
* **MDE for Linux Troubleshooting:** https://learn.microsoft.com/defender-endpoint/linux-support-install
* **Defender for Endpoint for US Government:** https://learn.microsoft.com/defender-endpoint/gov
* **Microsoft Defender Antivirus on Linux:** https://learn.microsoft.com/defender-endpoint/microsoft-defender-antivirus-linux

---

## 11. FIELD GOTCHAS FROM PREVIOUS DEPLOYMENTS

Use this section as a final go/no-go check before broad deployment.

### Common Gotchas to Validate

* ☐ **SSL/TLS certificate store is complete and current**
  * Confirm all required CA certificates are present in system trust store
  * Missing trust anchors can cause connectivity failures even when DNS/TCP checks pass
  * ```bash
    sudo update-ca-certificates  # Ubuntu/Debian
    sudo update-ca-trust  # RHEL/CentOS
    ```

* ☐ **Kernel eBPF support is enabled**
  * EDR functionality requires kernel eBPF (in-kernel virtual machine)
  * Systems with custom kernels or older RHEL 6 versions may lack support
  * Verify with: `grep CONFIG_HAVE_EBPF_JIT /boot/config-$(uname -r)`

* ☐ **Package manager repositories are accessible and current**
  * MDE packages depend on curl, openssl, and other common libraries
  * Verify yum/apt can reach Microsoft repositories before broad deployment
  * Test on pilot servers first

* ☐ **Network egress rules are not asymmetrical**
  * Some firewall configurations allow inbound but not outbound by default
  * Verify servers can reach MDE endpoints from ALL subnets where they'll be deployed
  * Test from multiple network segments if segmented

* ☐ **SELinux/AppArmor policies don't block MDE processes**
  * SELinux in enforcing mode can prevent MDE from binding to network sockets
  * AppArmor on Ubuntu/SLES may restrict MDE binary execution
  * Either add MDE to exception policies or switch to permissive/complain mode initially
  * ```bash
    getenforce  # Check SELinux status
    aa-status   # Check AppArmor status
    ```

* ☐ **Third-party security software doesn't interfere**
  * Host-based firewalls (fail2ban) may accidentally block MDE connections
  * Third-party EDR may conflict if already installed (choose one solution)
  * Document all security tools before deployment; test in lab environment first

* ☐ **Systemd is the init system** (not sysvinit)
  * MDE service management relies on systemd
  * Older systems with init scripts will require manual service management
  * Verify: `ps --no-headers -o comm 1 | grep systemd`

* ☐ **Disk space is sufficient for agent + threat intelligence**
  * MDE agent + definitions typically consume 2-5 GB after full installation
  * Audit logs can grow rapidly if high-volume servers; plan log rotation
  * Ensure >= 10 GB available on / and /var
  * Monitor disk usage during pilot phase

* ☐ **Agent version is >= 101.88.xx** (DoD IL5 requirement)
  * Earlier versions lack critical DoD environment fixes
  * Verify after installation: `mdatp -v`
  * Test updates with `sudo mdatp threat-intelligence-definition-status` and monitor service logs

* ☐ **Onboarding package is for correct environment (DoD vs Commercial)**
  * Onboarding package is environment-specific (DoD, GCC-High, Commercial)
  * Using wrong package will cause connectivity/authentication failures
  * Verify: Go to https://securitycenter.microsoft.us and select correct environment before downloading

* ☐ **Proxy configuration is correct** (if applicable)
  * MDE must be configured with proxy settings if environment requires outbound proxy
  * Direct connectivity test may pass while proxy configuration fails
  * Test proxy connectivity before broad deployment
  * Use curl via proxy to verify: `curl --proxy [proxy]:port https://x.cp.wd.microsoft.us/`

* ☐ **Firewall rule scope is correct** (host-based vs network-based)
  * Host-based firewall (iptables/firewalld) must allow all MDE endpoint FQDNs
  * Network firewalls must allow egress to MDE FQDN ranges (use DNS-based rules if available)
  * Test from multiple subnets; some segmented networks may have different rules

* ☐ **MDE Portal Advanced Settings are reviewed before broad deployment**
  * Device groups are created for organization
  * Automation rules are configured (auto-quarantine, isolation, etc.)
  * AIR investigation level matches organization risk tolerance
  * ASR rules are configured appropriately (block vs audit)

* ☐ **Portal registration timeline is communicated to stakeholders**
  * Expect 5-10 minutes for device to appear in portal
  * Expect 24-48 hours for full inventory/asset data to populate
  * Set realistic SLAs to prevent false "deployment failed" alerts

* ☐ **Pilot phase has clear success criteria**
  * Define acceptable baseline: CPU, memory, disk I/O, network bandwidth
  * Document detection trigger testing (if applicable in lab)
  * Get sign-off from application owners and IT operations

* ☐ **Rollback/uninstall procedure is documented**
  * Test uninstall process on non-production servers first
  * Uninstall command: `sudo yum remove mdatp` or `sudo apt remove mdatp`
  * Verify agent removal does not affect application functionality

* ☐ **Ongoing support & escalation path is defined**
  * Document Microsoft Support contact and SLA
  * Identify internal team responsible for MDE administration
  * Set up regular health reviews (weekly, monthly) for early issue detection

---

## DEPLOYMENT CHECKLIST

**Use this checklist as gate for each phase:**

### Pre-Deployment Phase
- [ ] Licensing validated (Defender for Endpoint Plan 2 or Defender for Servers Plan 2)
- [ ] All supported distributions identified
- [ ] Network connectivity verified (all MDE endpoints accessible)
- [ ] Firewall rules configured and tested
- [ ] SSL/TLS certificate store validated on representative servers
- [ ] Kernel eBPF support verified (if applicable)
- [ ] Package managers tested and repositories accessible
- [ ] SELinux/AppArmor impact assessed
- [ ] Third-party security software inventory completed
- [ ] Pilot servers identified and approved by stakeholders
- [ ] Microsoft Defender portal access confirmed
- [ ] Onboarding package downloaded (correct environment)

### Installation Phase (Pilot)
- [ ] MDE agent installed on pilot servers
- [ ] Agent service started successfully
- [ ] Agent version verified (>= 101.88.xx)
- [ ] Onboarding script executed successfully
- [ ] Org ID confirmed in `mdatp health` output

### Validation Phase (Pilot)
- [ ] Devices appear in Defender portal (5-10 minutes)
- [ ] Device health status = "Active"
- [ ] Sensor health status = "Active"
- [ ] Threat intelligence definitions current (< 24 hours)
- [ ] Telemetry events visible in portal
- [ ] Agent logs show no critical errors
- [ ] No adverse impact on application performance observed
- [ ] No unexpected process blocks/quarantines

### Production Rollout Phase
- [ ] Pilot validation passed (no blocking issues)
- [ ] Broad deployment plan and timeline approved
- [ ] Device groups created in Defender portal for all deployment waves
- [ ] Automation/remediation rules configured
- [ ] Email alerts configured for critical detections
- [ ] SOC team trained on Defender portal navigation and incident response
- [ ] Rollback/escalation procedure tested and documented
- [ ] Deployment executed per approved timeline
- [ ] Ongoing health monitoring established (weekly reviews)

---

**Document Version:** 1.0  
**Last Updated:** March 2026  
**Owner:** Linux Security Onboarding Team  
**Distribution:** Internal Use Only (IL5 / DoD)
