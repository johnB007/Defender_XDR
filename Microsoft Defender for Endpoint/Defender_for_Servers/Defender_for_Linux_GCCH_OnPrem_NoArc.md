# MDE and Defender Antivirus for Linux on premises in GCC High without Azure Arc

Reviewed against Microsoft documentation on 27 October 2026.

## 1. Purpose and deployment boundary

Install Microsoft Defender for Endpoint (MDE), including Microsoft Defender Antivirus (MDAV), directly on a supported Linux server. The `mdatp` package provides both components. There is no separate Windows Defender Antivirus installer for Linux.

This procedure does not install Azure Arc, create an Azure resource, enable Defender for Cloud, register a subscription, deploy an extension, or install the Azure Monitor agent. MDE uses its own telemetry pipeline. A standalone server entitlement and a tenant specific onboarding package are required.

The original `Defender_for_Linux.md` is preserved. Its DoD settings, historical distribution matrix, repository examples and validation commands are not prerequisites for this procedure. Do not copy its `101.88.xx` version floor, `mdatp-latest` package name, generic `x.cp.wd.microsoft.us` test, or its Windows specific dependencies into this deployment.

**Deployment gate:** This guide is prepared for an operator verified GCC High tenant. An IL4 designation alone does not establish GCC High, DoD, GCC, an MDE service region, or approval to send telemetry or samples. Do not run installation or onboarding until the tenant administrator and authorization owner have completed section 2. A documented DoD alternative is included only for an explicitly verified DoD tenant.

## 2. Mandatory operator verification

Complete this record in an approved internal change system, not in this repository. Do not publish tenant identifiers, onboarding files, diagnostics, device names, proxy details or customer data.

| Required decision | Evidence required before proceeding |
| :--- | :--- |
| Tenant cloud | Tenant administrator confirms GCC High or DoD and verifies the intended Defender portal and organization |
| Expected organization | Record the expected MDE organization identifier from trusted tenant evidence or a known correctly onboarded device; do not assume it equals the Entra directory identifier |
| Server entitlement | Licensing owner confirms sufficient standalone MDE server licenses for the verified government cloud |
| Linux support | Exact distribution, release, architecture, kernel, filesystem and workload are checked against the current Linux prerequisites |
| Connectivity mode | Standard, or explicitly approved government Streamlined preview; record the mode of the downloaded onboarding package |
| Package provenance | Linux Server package obtained by an authorized administrator from the verified tenant and transferred through the approved software process |
| Network approval | Linux applicable endpoint rows, installation sources, update sources and proxy behavior approved by the network and authorization owners |
| Protection policy | Primary antivirus, exclusions, sample submission, cloud protection, diagnostics and data handling reviewed for the workload |
| Change approval | Pilot server, maintenance window, rollback owner and evidence storage approved |

### Cloud selection

| Verified customer cloud | Human Defender portal | Government identity endpoint | Linux configuration URL | SmartScreen URL |
| :--- | :--- | :--- | :--- | :--- |
| GCC High | `https://security.microsoft.us` | `https://login.microsoftonline.us` | `https://config.ecs.gov.teams.microsoft.us/config/v1` | `unitedstates1.ss.wd.microsoft.us` |
| DoD | `https://security.apps.mil` | `https://login.microsoftonline.us` | `https://config.ecs.dod.teams.microsoft.us/config/v1` | `unitedstates2.ss.wd.microsoft.us` |

GCC is a different customer type. Microsoft lists `https://security.microsoft.com` for GCC. If the administrator confirms GCC, commercial service hosting, or any other cloud instead, stop and obtain the matching onboarding and network plan. A shared package storage hostname does not prove that two tenants or clouds use interchangeable onboarding content. [1][2]

IL4 describes an impact level and authorization context. Microsoft's Azure IL4 article discusses Azure Government authorization scope; it is not evidence that a particular MDE tenant is DoD, nor that this customer's telemetry and sample flows are authorized. Obtain the applicable service authorization evidence and the customer's approval separately. [10]

### Licensing and capabilities

Use the standalone **Microsoft Defender for Endpoint Server for GCC High** entitlement, or **Microsoft Defender for Endpoint Server for DOD** for a confirmed DoD tenant. Microsoft's government licensing table lists these separately from Defender for Servers. A user M365 E5 or MDE Plan 2 desktop entitlement alone is not evidence of server licensing. Confirm procurement terms and server counts with the licensing owner. Do not enable Defender for Servers or its direct onboarding billing integration as a substitute in this procedure. [1][4]

Microsoft lists Linux as supported in GCC High and DoD. That does not establish complete commercial feature parity, Linux support for every Windows feature, or the customer's authority to use every capability. This guide targets antivirus, EDR onboarding and health verification. Vulnerability management depends on the purchased entitlement and supported Linux capabilities; it does not require adding Defender for Cloud here.

The government feature matrix lists gaps including Microsoft Threat Experts and enterprise IoT security, and identifies vulnerability management reporting limitations. Mobile feature tables are not proof of Linux functionality. Validate government availability, Linux support, version requirements and tenant configuration before enabling Network Protection, Live Response, device isolation, central security configuration or other optional functions. This guide does not enable them or promise automated remediation parity. [1][4]

## 3. Linux prerequisites

Use the [current Microsoft Linux prerequisites](https://learn.microsoft.com/en-us/defender-endpoint/mde-linux-prerequisites) as the support authority, not the age of an available repository package. [4]

1. Use a supported vendor distribution and architecture. The examples below intentionally cover only RHEL 8 or 9 and Ubuntu LTS 22.04 or 24.04. Other supported releases need their own matching official installation instructions.
2. Verify systemd, administrative access, a working distribution package source, Python 3 for the onboarding script, current CA trust and working DNS and time synchronization.
3. Microsoft's baseline is one CPU core, 1 GB RAM and 2 GB disk. Size above that for the workload, retained logs and scan activity. The current documented minimum kernel is `3.10.0-327`; distribution, architecture and feature requirements still apply.
4. Confirm the application data filesystem is supported for the intended scan type. A supported OS does not imply real time protection for every network filesystem.
5. Review existing antivirus and EDR software. Two blocking Fanotify antivirus products are not a supported general configuration. Resolve coexistence before installing active MDAV. Do not disable SELinux, AppArmor or other security controls as a shortcut.
6. Install a current supported production agent. Microsoft documents automatic product version expiry after nine months. Plan package updates separately from security intelligence updates.
7. Check the current matrix again on the deployment date. For example, Microsoft currently states Amazon Linux 2 on ARM64 support ends on 31 October 2026. A repository existing for an older OS is not a support guarantee. [4][7]

Read only checks on the target Linux server:

```bash
cat /etc/os-release
uname -m
uname -r
ps -p 1 -o comm=
df -h / /var /opt
free -m
timedatectl status
command -v python3
command -v curl
```

Do not run these commands on the Windows authoring machine. They do not prove cloud identity or network readiness.

## 4. Network plan

All service connections below are initiated outbound by the device or the explicitly identified management workstation. HTTPS uses TCP 443 unless noted. No inbound management rule is required by this guide.

Use either approved Standard connectivity or approved government Streamlined preview. Do not choose a smaller allowlist while using a package for a different connectivity mode.

MDE on Linux does not support PAC, WPAD, authenticated proxies, TLS inspection or intercepting proxies. Use supported static or transparent proxy access with anonymous service traffic and no TLS interception. Importing the inspection CA does not make interception supported. Configure the service proxy separately from package manager or interactive shell proxy settings using the [Linux proxy instructions](https://learn.microsoft.com/en-us/defender-endpoint/linux-static-proxy-configuration). Never put credentials into a proxy URL in this guide. [4][8]

### 4.1 Standard connectivity for verified GCC High

The following service destinations have Linux marked Yes in the government Standard table. Keep the current Microsoft table as the authority and review all applicable rows at change time. Entries in one cell are separate destinations, not interchangeable alternatives. [2]

| Function | Destination | Port |
| :--- | :--- | :--- |
| Cloud protection and security intelligence | `unitedstates1.x.cp.wd.microsoft.us` | 443 |
| EDR cyber data | `us4-v20.events.data.microsoft.com` | 443 |
| Command and control | `winatp-gw-usgt.microsoft.com` | 443 |
| Malware sample storage | `ussusg1virginiaff0.blob.core.usgovcloudapi.net`, `ussusg2virginiaff0.blob.core.usgovcloudapi.net` | 443 |
| Malware sample storage | `ussusg1texasff0.blob.core.usgovcloudapi.net`, `ussusg2texasff0.blob.core.usgovcloudapi.net` | 443 |
| Common telemetry | `events.data.microsoft.com` | 443 |
| SmartScreen and related protection services | `unitedstates1.ss.wd.microsoft.us` | 443 |

Also retain the Linux configuration URL for GCC High in section 2, the certificate rows in section 4.4 and the installation and update dependencies in section 4.5.

The Standard table does not mark its GCC High AutoIR storage row as Linux. Do not infer Linux automated investigation support from that Windows row. Likewise its Windows MAPS entry `unitedstates1.cp.wd.microsoft.us` is not a substitute for the Linux `unitedstates1.x.cp.wd.microsoft.us` entry.

### 4.2 Standard connectivity for verified DoD only

Do not add this set merely because the server is described as IL4. Use it instead of the GCC High specific rows only when the tenant administrator has verified DoD. The common telemetry and certificate dependencies still apply. [2]

| Function | Destination | Port |
| :--- | :--- | :--- |
| Cloud protection and security intelligence | `unitedstates2.x.cp.wd.microsoft.us` | 443 |
| EDR cyber data | `us4-v20.events.data.microsoft.com` | 443 |
| Command and control | `winatp-gw-usgt.microsoft.com`, `winatp-gw-usgv.microsoft.com` | 443 |
| AutoIR sample storage rows marked Linux | `automatedirstrffusgt.blob.core.usgovcloudapi.net`, `automatedirstrffusgv.blob.core.usgovcloudapi.net` | 443 |
| Malware sample storage rows marked Linux | `ussusd1centralff5.blob.core.usgovcloudapi.net`, `wsusd1centralff5.blob.core.usgovcloudapi.net` | 443 |
| Malware sample storage rows marked Linux | `ussusd1eastff5.blob.core.usgovcloudapi.net`, `ussusd2eastff5.blob.core.usgovcloudapi.net` | 443 |
| Common telemetry | `events.data.microsoft.com` | 443 |
| SmartScreen and related protection services | `unitedstates2.ss.wd.microsoft.us` | 443 |

Retain the DoD Linux configuration URL in section 2. Storage names above reproduce the current Linux applicable rows exactly. Do not create additional names by changing a region, suffix or digit. A network row describing AutoIR storage does not itself guarantee a Linux response capability.

### 4.3 Government Streamlined preview

Use only after the tenant administrator confirms the option is available and the authorization owner approves preview use. Otherwise use the Standard procedure and its matching package.

| Function | Destination | Port |
| :--- | :--- | :--- |
| Consolidated core MDE services | `*.endpoint.security.microsoft.us` | 443 |
| GCC High SmartScreen | `unitedstates1.ss.wd.microsoft.us` | 443 |
| GCC High Linux internal configuration | `https://config.ecs.gov.teams.microsoft.us/config/v1` | 443 |
| DoD SmartScreen, only for DoD | `unitedstates2.ss.wd.microsoft.us` | 443 |
| DoD Linux internal configuration, only for DoD | `https://config.ecs.dod.teams.microsoft.us/config/v1` | 443 |

Use the two rows for the verified cloud, not both clouds by default. Keep certificate, package and security intelligence update dependencies. The consolidated domain replaces core cloud protection, sample storage, command and control, and cyber and diagnostic data destinations; it does not consolidate all Linux updates or portal downloads. Microsoft lists Linux version `101.24022.*` or later as the Streamlined minimum. Install a current supported production release, not that historical minimum. [3][6]

**Documentation discrepancy requiring care:** The Standard government page also contains a generic WW consolidated row ending in `.com`. The dedicated government Streamlined page and current connectivity overview explicitly identify `.us` for government preview. Use those government specific sources for that mode; do not change domains mechanically or use the WW row to select a tenant cloud. If the selected tenant package or actual client destinations conflict with the approved government plan, stop and resolve with Microsoft Support before widening access. [2][3][6]

### 4.4 Certificate checks and platform distinctions

Both government tables mark these certificate destinations as Linux applicable. Allow TCP 80 as documented. Do not replace these with invented government domains. [2][3]

| Destination |
| :--- |
| `http://crl.microsoft.com/pki/crl/*` |
| `http://www.microsoft.com/pkiops/*` |
| `http://www.microsoft.com/pki/certs` |

The `ctldl.windowsupdate.com` row has no Linux Yes marker. WNS and its Live Response authentication rows are Windows specific in these tables. Do not label them mandatory Linux dependencies. Validate Linux Live Response separately if that feature is later approved.

Wildcards and URL paths require a firewall or proxy that supports those rule types. Linux `iptables` cannot implement a wildcard hostname allowlist. Do not convert a single DNS response into a permanent Microsoft service IP list.

### 4.5 Installation packages and antivirus updates

| Flow | Source or mechanism | Scope |
| :--- | :--- | :--- |
| Production agent, repository metadata and Microsoft public signing keys | `https://packages.microsoft.com` using the exact official distro configuration | Linux server, or an approved internal package mirror |
| Distribution dependencies and CA updates | Approved distribution repositories or approved internal mirrors | Linux server |
| Security intelligence online checks | Linux connectivity guidance tests `https://cdn.x.cp.wd.microsoft.com/ping`, also regional CDN checks such as `eu-cdn.x.cp.wd.microsoft.com` and `wu-cdn.x.cp.wd.microsoft.com` | Review the official Linux connectivity guidance and selected client's actual tests |
| Standard cloud protection and intelligence | The verified cloud's `unitedstates1.x.cp.wd.microsoft.us` or `unitedstates2.x.cp.wd.microsoft.us` | Linux server using Standard mode |
| Offline security intelligence mirror acquisition | `https://github.com/microsoft/mdatp-xplat.git`, `https://go.microsoft.com/fwlink/?linkid=2144709`, `https://definitionupdates.microsoft.com` | Approved mirror acquisition host only, when that method is chosen |

Microsoft documents public `.com` package and update sources. Government service hosting does not mean every supporting download uses `.us`. Do not invent `packages.microsoft.us`, rewrite CDN names, or treat a Windows Update, WSUS or Configuration Manager row as a Linux update design.

The Standard government table has uneven Mac/Linux CDN applicability markers and references a Mac updater channel. Use the Linux installation, update and connectivity articles to establish Linux package and CDN behavior. Do not substitute Mac Microsoft AutoUpdate instructions for Linux. If the authorization boundary disallows a documented public dependency, obtain an approved mirror design or Microsoft clarification before deployment. This is not permission to allow all commercial telemetry endpoints. [2][5][7][8]

For restricted networks, Microsoft's Linux offline intelligence method supports an internal web server or mounted share, agent version `101.24022.0001` or later, and explicit fallback control. The mirror downloads current signed content; product packages still need a separate update process. With no approved public fallback, configure `offlineDefinitionUpdateFallbackToCloud` to `false` in the approved managed policy and verify the configured source. Do not overwrite an existing managed policy file with a sample.

Offline intelligence updates do not make EDR, cloud protection, device reporting or response work without their required cloud connectivity. The documentation does not, by itself, establish approval of this mirror method for this customer's government boundary. Obtain that approval and validate the pilot. [9]

### 4.6 Portal access and package acquisition

These are administrator workstation or approved package acquisition dependencies, not proof that every Linux server needs browser identity access. The government portal tables list common dependencies:

| Purpose | Documented destination |
| :--- | :--- |
| Portal storage | `*.blob.core.usgovcloudapi.net` |
| Portal certificate checks | `crl.microsoft.com` |
| Portal authentication assets | `https://*.microsoftonline-p.com`, `https://secure.aadcdn.microsoftonline-p.com` |
| Portal static assets | `https://static2.sharepointonline.com` |
| GCC High and DoD identity | `https://login.microsoftonline.us` |
| Government service dependencies | `https://*.securitycenter.microsoft.us` |
| GCC High and DoD onboarding package download | `https://onboardingpckgsusgvprd.blob.core.usgovcloudapi.net` |

Use the human portal in section 2 to obtain the package. A storage root is not a complete downloadable package URL and must not be used to fabricate one. Transfer the downloaded package to the server through the approved internal process. Onboarding files are tenant configuration artifacts, not public repository content. [1][2][3]

## 5. Install the production agent

These are operator executed Linux commands after change approval. They have not been executed against a server as part of preparing this guide. Do not paste every distro block into one terminal. Choose exactly the block matching the supported target.

Before installing, approve repository trust through your software supply process. Do not disable signature checking. These examples retrieve Microsoft's documented public key; the repository configuration and signing key must match the chosen distro. Do not replace a current working Microsoft repository configuration blindly.

### Option A: RHEL 8 or 9 only

Run in Bash. This block stops on another distribution or release. It uses DNF 4 syntax documented for these releases, not RHEL 10 or DNF 5 syntax.

```bash
(
set -euo pipefail
. /etc/os-release
[[ "$ID" == rhel ]] || { printf '%s\n' 'STOP: RHEL required.' >&2; exit 1; }
case "$VERSION_ID" in
  8|8.*) major=8 ;;
  9|9.*) major=9 ;;
  *) printf '%s\n' 'STOP: Use the official instructions for this release.' >&2; exit 1 ;;
esac
sudo dnf install dnf-plugins-core curl ca-certificates python3
sudo dnf config-manager --add-repo "https://packages.microsoft.com/config/rhel/${major}/prod.repo"
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install mdatp
sudo systemctl enable --now mdatp
systemctl is-active mdatp
)
```

### Option B: Ubuntu LTS 22.04 or 24.04 only

Run in Bash. The two releases use different documented key locations. This block refuses to replace an existing `microsoft-prod.list`. If that file exists, review it and its signing configuration using the official instructions instead of deleting it.

```bash
(
set -euo pipefail
. /etc/os-release
[[ "$ID" == ubuntu ]] || { printf '%s\n' 'STOP: Ubuntu required.' >&2; exit 1; }
case "$VERSION_ID" in
  22.04) keyring=/etc/apt/trusted.gpg.d/microsoft.gpg ;;
  24.04) keyring=/usr/share/keyrings/microsoft-prod.gpg ;;
  *) printf '%s\n' 'STOP: Use the official instructions for this release.' >&2; exit 1 ;;
esac
[[ ! -e /etc/apt/sources.list.d/microsoft-prod.list ]] || {
  printf '%s\n' 'STOP: Review the existing Microsoft repository configuration.' >&2
  exit 1
}
sudo apt-get update
sudo apt-get install curl gpg ca-certificates apt-transport-https libplist-utils python3
workdir="$(mktemp -d)"
trap 'rm -rf -- "$workdir"' EXIT
curl --fail --show-error --silent --location \
  "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/prod.list" \
  --output "$workdir/microsoft-prod.list"
curl --fail --show-error --silent --location \
  https://packages.microsoft.com/keys/microsoft.asc --output "$workdir/microsoft.asc"
gpg --batch --dearmor --output "$workdir/microsoft.gpg" "$workdir/microsoft.asc"
sudo install -m 0644 "$workdir/microsoft.gpg" "$keyring"
sudo install -m 0644 "$workdir/microsoft-prod.list" /etc/apt/sources.list.d/microsoft-prod.list
sudo apt-get update
sudo apt-get install mdatp
sudo systemctl enable --now mdatp
systemctl is-active mdatp
)
```

Neither block uses `curl | bash`, rewrites a Debian repository line into a RHEL repo file, installs `mdatp-latest`, upgrades the whole OS, or turns off platform protections. For SLES, Debian, Oracle Linux, other releases or an internal repository, use the matching [manual installation instructions](https://learn.microsoft.com/en-us/defender-endpoint/linux-install-manually). [5]

## 6. Obtain and apply the correct onboarding package

1. On the approved administrator workstation, open the verified tenant's portal from section 2.
2. Go to **System > Settings > Endpoints > Device management > Onboarding**.
3. Select **Linux Server** and **Local Script**. Confirm the recorded connectivity mode. For approved Streamlined preview, select **Streamlined** if available and download its corresponding package. Do not assume Standard and Streamlined packages are equivalent.
4. Download the package from that tenant. Microsoft's manual guide names the ZIP `WindowsDefenderATPOnboardingPackage.zip` despite the Linux selection, and the extracted file `MicrosoftDefenderATPOnboardingLinuxServer.py`. Check the actual downloaded contents.
5. Inspect the package locally using the approved software review process. Confirm provenance, tenant, cloud and connectivity mode. Do not edit embedded routing, organization data or signatures to convert a package between clouds.
6. Transfer the approved script to a protected directory on the Linux server. Record an acquisition hash and verify it after transfer with `sha256sum`. A matching transfer hash does not independently prove tenant provenance.
7. Before running it, inspect `mdatp health`. If the server is already associated with any organization, stop and plan the supported migration or offboarding process. Do not silently overwrite an existing association. [5][6]

The following Bash block requires operator confirmation and local input. No default tenant or cloud is embedded. It refuses to onboard an already associated device. The expected organization value must be the MDE organization identifier verified in section 2, not an assumed Entra identifier.

```bash
(
set -euo pipefail
read -r -p 'Verified cloud (GCCH or DoD): ' verified_cloud
case "$verified_cloud" in
  GCCH|DoD) ;;
  *) printf '%s\n' 'STOP: Verify the tenant cloud first.' >&2; exit 1 ;;
esac
read -r -p 'Expected MDE organization identifier: ' expected_org
[[ -n "$expected_org" ]] || { printf '%s\n' 'STOP: Organization evidence required.' >&2; exit 1; }
read -r -p 'Absolute path to reviewed Linux onboarding Python file: ' onboarding_script
[[ "$onboarding_script" == /* && -f "$onboarding_script" ]] || {
  printf '%s\n' 'STOP: A reviewed local onboarding file is required.' >&2
  exit 1
}
read -r -p 'Tenant, cloud, connectivity, transfer hash and change approval verified (YES): ' approved
[[ "$approved" == YES ]] || { printf '%s\n' 'STOP: Approval required.' >&2; exit 1; }
current_org="$(mdatp health --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["org_id"] or "")')"
[[ -z "$current_org" ]] || {
  printf '%s\n' 'STOP: Device already associated. Use the approved migration process.' >&2
  exit 1
}
sudo python3 "$onboarding_script"
actual_org="$(mdatp health --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["org_id"] or "")')"
[[ "$actual_org" == "$expected_org" ]] || {
  printf '%s\n' 'STOP: Organization mismatch or onboarding pending. Investigate without rerunning.' >&2
  exit 1
}
printf '%s\n' 'Organization matched. Complete protection and portal acceptance checks.'
)
```

This block cannot establish cloud identity from a typed label. Its gate relies on the verified package and administrator evidence. A matching organization does not prove that every network dependency or protection setting is healthy.

## 7. Configure MDAV and verify health

Use the approved Linux managed policy for production. Review any existing `/etc/opt/microsoft/mdatp/managed/mdatp_managed.json`; do not overwrite it. Settings marked managed may reject local changes. Resolve policy ownership instead of bypassing controls.

After confirming no antivirus conflict and approval to make MDAV the primary antivirus, these documented commands disable passive mode and enable real time protection:

```bash
sudo mdatp config passive-mode --value disabled
sudo mdatp config real-time-protection --value enabled
```

Passive mode is not successful delivery of the requested active MDAV protection. Do not force active mode while another incompatible blocking product remains. Cloud protection and automatic sample submission require an approved data handling decision. Do not automatically enable sample upload merely to make a field show true. Local antivirus and cloud service capabilities must be assessed separately when policy restricts data transfer. [4][11]

Run on the onboarded Linux server using the configured service network path:

```bash
systemctl is-active mdatp
mdatp health
mdatp health --field org_id
mdatp health --field healthy
mdatp health --field licensed
mdatp health --field app_version
mdatp health --field product_expiration
mdatp health --field real_time_protection_enabled
mdatp health --details definitions
mdatp connectivity test
```

Trigger a security intelligence update from the approved configured source and recheck:

```bash
sudo mdatp definitions update
mdatp health --details definitions
```

Do not use the unsupported commands `mdatp telemetry`, `mdatp threat-intelligence-definition-status`, or `mdatp config real-time-protection --set=on` from older notes. Use the documented CLI for the installed version. [5][8][9][11]

### Acceptance evidence

| Check | Required evidence |
| :--- | :--- |
| Service | `mdatp` active with no unresolved startup errors |
| Organization | `org_id` matches the privately recorded expected MDE organization |
| Entitlement | `licensed` true plus procurement evidence; a local true flag alone does not prove contractual entitlement |
| Product health | `healthy` true and no unexplained health issues |
| Active antivirus | Real time protection true, passive mode disabled, no unresolved conflicting application |
| Intelligence | `definitions_status` is `up_to_date`, recent update time, expected source and no update failure reason |
| Agent currency | Current approved production version with a future product expiration |
| Cloud connectivity | Applicable checks pass and destinations align with the verified cloud and package mode |
| Portal | Correct server appears in the verified tenant device inventory with current sensor status and recent timeline data |
| Policy | Effective protection, samples, diagnostics and exclusions match the approved baseline |

Initial intelligence download can briefly leave health false. Microsoft states first device appearance can take up to 20 minutes. Do not declare success based only on package installation, an organization identifier, ping, an open TCP port, a generic HTTP 401 or 403, or a listening socket. Portal visibility and current telemetry need separate evidence. [5]

The Linux connectivity article shows commercial example output. Do not blindly allow every hostname printed before onboarding. After applying the verified package, compare tests and actual traffic with the approved government plan. Unexpected commercial core routing, absent cloud evidence, or blocked required dependencies are stop conditions, not reasons to rewrite an endpoint. [8]

Antivirus test files and Microsoft's Linux EDR simulation create detections and alerts. Perform them only with separate test authorization on a pilot under the change plan. No detection simulation is included in the automatic steps here. If approved, use the separate antivirus and EDR tests in Microsoft's manual deployment article and confirm the corresponding portal evidence. An antivirus test alone does not prove EDR reporting. [5]

## 8. Ongoing updates and troubleshooting

Without Defender for Cloud provisioning, the operator owns agent maintenance. Schedule production package updates through the approved package system. Intelligence updates do not renew an expired product version. Use only the command for the installed distro: [7]

```bash
sudo dnf upgrade mdatp
```

```bash
sudo apt-get update
sudo apt-get install --only-upgrade mdatp
```

If onboarding or health fails:

1. Confirm tenant, package provenance, connectivity mode, organization and licensing first. Do not repeatedly onboard or try the other government cloud as a troubleshooting guess.
2. Examine `mdatp health`, `mdatp health --details definitions` and `mdatp connectivity test`. Check DNS, clock, CA trust, package access, proxy behavior, policy and certificate interception.
3. Review `/var/log/microsoft/mdatp/install.log` for installation failures. If support diagnostics are approved, use `sudo mdatp diagnostic create`. Store the generated archive only in approved evidence storage.
4. Resolve government documentation discrepancies with Microsoft Support and the authorization owner if they affect the chosen route. Do not upload logs or tenant packages to GitHub.
5. If rollback is needed, use the verified tenant's supported Linux offboarding process under change approval before removing the package. Do not merely delete the onboarding configuration or remove the service and assume offboarding has completed. Offboarding and uninstalling reduce protection. [11][12]

## 9. Research and validation record

This document was checked against the official sources below. Local validation covers Markdown structure, embedded Bash syntax and HTML rendering only. No package was installed, no onboarding script or command block was executed, no customer tenant was contacted, no resource was changed, and no live Linux connectivity, licensing or protection result is claimed.

The earlier conversational reference described as the other link was not recovered in a bounded recent history lookup. The government Standard and Streamlined references below independently establish the cloud distinctions and current URL evidence. Do not assume either is the previously supplied link.

Deployment remains conditional on the operator evidence in section 2. In particular, IL4 authorization, the actual tenant cloud, exact Linux release and architecture, server entitlement, connectivity mode, and approval of supporting public download sources are not known from the original request.

## 10. Authoritative sources

| Ref | Microsoft source | What it establishes |
| :--- | :--- | :--- |
| 1 | [MDE for US Government customers](https://learn.microsoft.com/en-us/defender-endpoint/gov) | Government server licenses, portal distinctions, Linux support and government feature gaps |
| 2 | [Government Standard connectivity URLs](https://learn.microsoft.com/en-us/defender-endpoint/standard-device-connectivity-urls-gov) | Exact government destinations and Linux applicability by row |
| 3 | [Government Streamlined connectivity URLs](https://learn.microsoft.com/en-us/defender-endpoint/streamlined-device-connectivity-urls-gov) | Government preview domain, Linux configuration endpoints and portal dependencies |
| 4 | [Linux prerequisites](https://learn.microsoft.com/en-us/defender-endpoint/mde-linux-prerequisites) | Server licensing requirement, distributions, architectures, resources, filesystems, coexistence and proxy restrictions |
| 5 | [Manual Linux deployment](https://learn.microsoft.com/en-us/defender-endpoint/linux-install-manually) | Distribution repositories, signing keys, package installation, Linux onboarding script and verification |
| 6 | [Streamlined onboarding](https://learn.microsoft.com/en-us/defender-endpoint/configure-device-connectivity) | Government versus commercial consolidated domains, minimum Linux version and matching onboarding package |
| 7 | [Linux product updates](https://learn.microsoft.com/en-us/defender-endpoint/linux-updates) | Product expiry and package updates distinct from intelligence updates |
| 8 | [Linux connectivity troubleshooting](https://learn.microsoft.com/en-us/defender-endpoint/linux-support-connectivity) | Connectivity test, Linux CDN examples and TLS interception restrictions |
| 9 | [Linux offline security intelligence](https://learn.microsoft.com/en-us/defender-endpoint/linux-support-offline-security-intelligence-update) | Mirror prerequisites, acquisition URLs, source verification and fallback control |
| 10 | [DoD IL4](https://learn.microsoft.com/en-us/azure/compliance/offerings/offering-dod-il4) | Impact level meaning and Azure Government authorization scope, not this MDE tenant's cloud selection |
| 11 | [Linux resources and CLI](https://learn.microsoft.com/en-us/defender-endpoint/linux-resources) | Supported antivirus commands, intelligence update command and diagnostic collection |
| 12 | [Linux offboarding](https://learn.microsoft.com/en-us/defender-endpoint/linux-off-board-endpoints) | Supported device offboarding workflow |

The HTML sibling is a local rendered preview only. Publish the Markdown only after explicit approval of the repository destination and change scope. Do not publish onboarding artifacts or generated HTML.
