# Prevention Measures Based on Workbook

## Purpose

The AI Activity and Exposure Investigation Workbook identifies how AI services are reached, who uses them, what devices and processes are involved, and where sensitive file, browser, automation, local AI, agent, and MCP evidence appears. This guide converts those investigation paths into prevention decisions for a Microsoft 365 E5 environment, starting with audit and controlled pilots before broad enforcement.

The workbook is evidence, not a block list. Use its users, devices, domains, processes, files, and command context to determine which controls fit the business need and which exceptions must be documented.

## Control Principles

1. Separate approved Microsoft 365 Copilot from consumer, unsanctioned, and developer AI services.
2. Protect sensitive data before it leaves a managed device, even when a service is approved.
3. Apply a control in audit or simulation mode first, measure impact, then enforce by user, device, or workload group.
4. Treat agents, local models, extensions, and MCP servers as software and data access surfaces, not only websites.
5. Maintain an exception process with an owner, business reason, expiration, and review date.

## 1. Network And Destination Controls

**Workbook evidence:** Unauthorized AI, Automation and API, and AI Application Discovery show destination domains, initiating processes, accounts, and affected devices.

**Control objective:** Prevent access to services the organization has not approved, while preserving a narrow, documented exception path.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| Web categories | Defender for Endpoint web content filtering | Start in audit mode for selected device groups. Block relevant categories only after reviewing observed impact. | Web protection reports and `DeviceNetworkEvents` |
| Specific AI destinations | Defender for Endpoint custom URL and domain indicators, SWG, proxy, firewall, or DNS filtering | Block known unsanctioned domains and allow approved destinations. Use the catalog as candidate reference data, not as an automatic enforcement list. | Block events, indicator statistics, and workbook domain results |
| Network protection | Defender for Endpoint network protection | Enable and verify browser coverage for supported browsers. | `DeviceNetworkEvents` and web protection reports |
| Approved service exceptions | Indicators and network policy | Document approved domains, scope, owner, and expiry. | Exception register and policy assignment |

Web content filtering is useful for category based control, but it is not a complete AI inventory. New sites can be uncategorized, classification can change, and custom indicators provide tighter destination control where required.

## 2. Sensitive Data Protection

**Workbook evidence:** Sensitive File and AI Correlation and AI Application Discovery identify file activity, browser paste events, sensitive information classifications, policy metadata, and AI destinations.

**Control objective:** Stop sensitive content from being pasted, uploaded, copied, or typed into AI prompts before it leaves a managed device.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| File protection | Microsoft Purview sensitivity labels with encryption | Apply labels and encryption to data classes that external AI services must not process. | Label coverage, DLP matches, and protected document tests |
| Browser paste and upload | Purview Endpoint DLP | Create device scoped rules for sensitive information types and labels. Start in simulation, then block paste to browser and upload to AI sites. | Activity Explorer, DLP alerts, and `CloudAppEvents` |
| Edge prompt protection | Purview Browser Data Security in Microsoft Edge | Block sensitive text typed or pasted into consumer AI prompts. | Browser policy reporting and controlled prompt tests |
| Alternative browser and app visibility | Purview Network Data Security where licensed and available | Detect sensitive data shared through non Edge browsers, applications, APIs, and add ins. | Network Data Security findings and investigation records |
| Clipboard control | Purview Endpoint DLP | Restrict copying sensitive content to the clipboard where the business case requires it. | DLP audit and block results |

A browser paste event proves that a paste action was observed. It does not prove the literal clipboard text was ingested into Sentinel or that the content was submitted successfully. Use Purview evidence and DLP activity for the supported evidence path.

## 3. Application And Local AI Control

**Workbook evidence:** Local AI identifies executable launches, installers, model files, and local packages. Automation and API identifies scripting runtimes and command line clients reaching AI destinations.

**Control objective:** Prevent unapproved local AI software and high risk developer tooling while preserving approved engineering workflows.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| Application allow list | Windows Defender Application Control or AppLocker | Begin in audit mode. Allow approved publishers and signed binaries; block or restrict unapproved local AI clients, model runners, and unsigned tools. | Code Integrity events and workbook Local AI results |
| Managed application deployment | Intune | Use managed app deployment and uninstall assignments for approved versus disallowed desktop AI clients. | Intune reporting and device inventory |
| Unsigned executable control | WDAC and Defender | Require signed or approved binaries for sensitive device groups. | Code Integrity, Defender alerts, and process evidence |
| Local model storage | Endpoint DLP and device management | Define whether local model files are permitted, where they may reside, and who can use them. | File evidence, DLP results, and device exceptions |

Do not broadly block every executable with an AI related word in its name. Start with publisher, hash, package source, device role, and observed command context to reduce false positives.

## 4. Script, Package, And API Governance

**Workbook evidence:** Automation and API identifies PowerShell, Python, Node, curl, command shells, process command lines, and AI endpoints.

**Control objective:** Reduce unreviewed automation and unmanaged API consumption without disabling legitimate engineering work.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| PowerShell | PowerShell execution policy, Constrained Language Mode, WDAC, Defender for Endpoint | Apply the least disruptive control that matches the device role. Monitor script block and process activity before enforcement. | `DeviceProcessEvents`, PowerShell logs, and Defender alerts |
| Python and Node packages | Intune, WDAC, proxy controls, developer platform policy | Restrict package installation sources or require approved registries for managed developer groups. Do not block Python or Node globally without a tested exception model. | Package management logs, process evidence, and developer exceptions |
| API destination access | Custom indicators, proxy, firewall, SWG | Restrict outbound API endpoints to approved services and approved device groups. | Network blocks and API process evidence |
| API secret handling | Defender for Cloud Apps, GitHub security controls, Defender for DevOps, Key Vault, code scanning | Detect exposed keys, move approved secrets to managed vaults, rotate compromised keys, and document API ownership. | Secret alerts, remediation tickets, and vault access logs |
| Azure AI resource governance | Azure Policy, Azure RBAC, Azure resource governance | Restrict who can create AI resources, deployments, and credentials. Require approved subscriptions, regions, and owners. | Policy compliance and Azure activity logs |

The goal is governed automation, not an assumption that every script or package is malicious. The workbook helps establish a baseline before controls are enforced.

## 5. Browser And Extension Control

**Workbook evidence:** AI Application Discovery identifies browser processes, browser destinations, paste evidence, and access through supported browsers.

**Control objective:** Reduce shadow AI access and extension based data exposure from unmanaged browsers.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| Managed browser | Microsoft Edge management service and Intune | Require managed Edge for protected workflows and configure browser security settings. | Intune policy status and browser telemetry |
| Extension allow list | Edge and Chrome extension policies through Intune or Group Policy | Allow approved extensions, block unknown or high risk AI assistant extensions, and review extension permissions. | Browser extension inventory and policy reports |
| Browser choice | Conditional Access and device compliance | Require compliant devices for cloud access and steer protected workflows to managed browsers. | Entra sign in logs and compliance reports |
| Consumer AI prompt protection | Purview Browser Data Security | Use Edge prompt protection for sensitive text scenarios. | DLP policy results and controlled tests |

Conditional Access does not independently inspect or block every AI website. Use it with managed device, managed browser, DLP, and destination controls.

## 6. MCP And Agent Controls

**Workbook evidence:** Agents and MCP identifies MCP commands, configuration files, agent instructions, executable launches, configured servers, and ownership.

**Control objective:** Treat MCP servers and agent tools as controlled integrations that can access data, invoke tools, and expand a developer or user workflow beyond a normal browser session.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| Approved server register | Security architecture and developer governance | Maintain an allow list of approved MCP servers, owners, data classifications, authentication method, tool permissions, and expiry. | Approved server register and exception reviews |
| MCP client and executable control | WDAC, AppLocker, Intune, and Defender for Endpoint | Audit then restrict unapproved local MCP clients and server executables on sensitive device groups. | Process events and Code Integrity evidence |
| Configuration file monitoring | Defender for Endpoint and file integrity processes | Monitor agent instruction and MCP configuration files for creation or change, then review server definitions and tool permissions. | `DeviceFileEvents` and workbook Agents and MCP results |
| VS Code governance | Intune, extension policies, WDAC, developer platform controls | Restrict extension installation to approved marketplaces or publisher allow lists for managed developer devices. | Extension inventory and policy compliance |
| Outbound server access | Custom indicators, proxy, firewall, SWG | Limit connections to approved MCP server destinations and require a documented exception for others. | Network events, indicator statistics, and exceptions |

MCP is not automatically remote code execution, but an MCP server can expose tools and data access to a client. Review the server's tool set, permissions, authentication, data scope, and network destination before approving it.

## 7. Identity, Device, And Access Conditions

**Workbook evidence:** All tabs provide user and device context needed to scope policy, target exceptions, and measure adoption.

**Control objective:** Ensure AI access and data sharing occur only from managed, compliant, and appropriately governed devices and identities.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| Device compliance | Intune and Conditional Access | Require compliant, managed devices for corporate AI services and sensitive data workflows. | Entra sign in logs and Intune compliance |
| Risk based access | Entra Conditional Access and Identity Protection | Apply stronger conditions for privileged users, high risk sign ins, and sensitive device groups. | Conditional Access reporting and sign in risk |
| Privileged administration | Privileged Identity Management and RBAC | Limit who can change DLP, web filtering, indicators, extension policies, and AI resource controls. | Role assignments and privileged access reviews |
| Exception governance | Service management and security governance | Require an owner, business purpose, expiry, and periodic recertification for every exception. | Exception register and review evidence |

## Recommended Rollout Sequence

1. Use the workbook to baseline current AI access, automation, local AI, browser, and MCP activity.
2. Classify services as approved, restricted, or prohibited with business and legal stakeholders.
3. Apply destination controls in audit mode to a pilot group and use workbook evidence to tune false positives.
4. Deploy sensitivity labels, Endpoint DLP simulation, and Edge prompt protections for sensitive data scenarios.
5. Move validated DLP and destination rules to block or block with override, with a documented exception path.
6. Deploy application control and extension allow lists to sensitive devices, then broaden scope in phases.
7. Establish agent and MCP approval governance before allowing broad developer use.
8. Review workbook trends, DLP incidents, block events, and exceptions at least monthly.

## Office Meeting Agenda

| Topic | Outcome |
| --- | --- |
| Approved AI service definition | Confirm Microsoft 365 Copilot and any approved alternatives |
| Data classes | Select sensitive information types and labels requiring protection |
| Pilot population | Select a representative user and device cohort |
| Control priority | Decide the first destination, DLP, application, extension, or MCP control to test |
| Exception path | Agree on owner, request process, expiry, and review cadence |
| Success measures | Define expected reduction in unapproved activity, DLP events, and policy exceptions |

## Control Boundaries

No single E5 control blocks every AI path. Use layered controls: destination enforcement limits where users can connect, data protection limits what can leave the device, application control limits what can execute, and identity controls limit which devices and users can use protected services. Keep the workbook in the loop as the measurement and investigation surface for each control change.

## Official References

* [Prevent data leak to shadow AI: block sensitive data going to sanctioned AI apps](https://learn.microsoft.com/purview/deploymentmodels/depmod-data-leak-shadow-ai-step3)
* [Web content filtering in Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/web-content-filtering)
* [Web protection in Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/web-protection-overview)
* [Diagnose Paste to supported browsers in Endpoint DLP](https://learn.microsoft.com/troubleshoot/microsoft-365/purview/data-loss-prevention/diagnose-paste-to-supported-browser-issues)