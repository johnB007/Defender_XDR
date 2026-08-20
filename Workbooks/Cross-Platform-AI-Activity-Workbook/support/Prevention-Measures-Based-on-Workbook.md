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

## 1. AI Service Access Governance

**Workbook evidence:** AI Activity Overview, Automation and API, and AI Application Discovery show AI destinations, initiating processes, accounts, and affected devices.

**Control objective:** Govern which AI services are approved, restricted, or unavailable for each user and device population based on business purpose and data risk. Use a documented exception path for legitimate services that are not part of the default approved set.

| Control | Microsoft control plane | Recommended action | Validation evidence |
| --- | --- | --- | --- |
| Web categories | Defender for Endpoint web content filtering | Start in audit mode for selected device groups. Use categories only where they support the organization's AI access policy and observed impact. | Web protection reports and `DeviceNetworkEvents` |
| Specific AI destinations | Defender for Endpoint custom URL and domain indicators, SWG, proxy, firewall, or DNS filtering | Allow approved destinations, restrict services that have not completed review, and use a documented business exception where needed. Use the catalog as candidate reference data, not as an automatic enforcement list. | Access decisions, indicator statistics, and workbook domain results |
| Network protection | Defender for Endpoint network protection | Enable and verify browser coverage for supported browsers. | `DeviceNetworkEvents` and web protection reports |
| Service exceptions | Indicators and network policy | Document the destination, user or device scope, owner, business purpose, expiry, and review date. | Exception register and policy assignment |

Web content filtering is useful for category based governance, but it is not a complete AI inventory. New sites can be uncategorized, classification can change, and custom indicators provide tighter destination decisions where required.

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

**Workbook evidence:** Automation and API identifies PowerShell, Python, Node, curl, command shells, process command lines, and AI endpoints. Use the tab to separate ordinary developer tooling from processes that send data or requests to an AI destination outside the approved service set.

**Control objective:** Make automated AI use attributable to an owner, an approved workload, an approved destination, and a managed secret. The objective is governed automation, not an assumption that every script, package, or developer is malicious.

### Command Line, Scripting, And Developer Runtimes

The workbook's Automation and API tab covers command shells, scripting engines, download clients, and developer runtimes when they reach an AI destination. The monitored process set includes `cmd`, `powershell`, `pwsh`, `wscript`, `cscript`, `python`, `node`, `curl`, `wget`, `bash`, `sh`, `zsh`, Jupyter, R, and Go tooling; it is not limited to PowerShell.

| Runtime or client | Recommended control model | What to review in the workbook |
| --- | --- | --- |
| `powershell.exe` and `pwsh.exe` | Start with App Control audit mode and PowerShell script block logging. Use trusted signer or publisher rules for approved scripts and modules, then use WDAC or App Control enforcement for sensitive populations. | Parent process, command line, AI destination, account, device, encoded commands, and repeated execution |
| `cmd.exe`, `wscript.exe`, and `cscript.exe` | Use WDAC or AppLocker audit mode to identify business dependencies, then restrict unapproved script hosts and unsigned scripts by device role. | Script host, child process, script path, AI destination, account, and device |
| `python.exe`, `python3.exe`, Jupyter, R, and Go | Define an approved developer device group, approved package sources, and approved project or workload owners. Use application control and egress policy to restrict use outside that model. | Runtime, package command line, virtual environment or project path, destination, account, and device |
| `node.exe`, `npm`, and `npx` | Define approved Node versions, registries, package sources, and VS Code extension policy for managed developer devices. Restrict unapproved AI clients and MCP packages through application control and destination policy. | Node command line, package install command, MCP configuration files, destination, account, and device |
| `curl` and `wget` | Permit only on approved administrative or developer devices where possible. Use custom indicators, SWG, proxy, firewall, or DNS controls to govern the API destinations they can contact. | Exact URL or domain, parent process, command parameters, device role, and request volume |
| `bash`, `sh`, and `zsh` | Apply equivalent Linux and macOS endpoint, package source, and network egress controls. Require a managed device and documented owner for AI automation. | Shell process, child process, command line, destination, account, and device |

PowerShell 7.4 and later can log App Control audit restrictions without failing the script, which makes audit mode the right first step for business critical automation. Script block logging and AMSI provide additional investigation evidence, but they do not replace App Control enforcement. Do not rely on PowerShell execution policy as the primary security boundary, and do not globally block Python, Node, or command line clients without a tested developer exception model.

### Python, Node, And Package Registries

| Decision | Recommended implementation | What to review in the workbook |
| --- | --- | --- |
| Managed developer devices | Define approved package registries, package sources, and developer groups. Use proxy, SWG, firewall, or DNS controls to restrict unapproved registry and AI API egress where the network architecture supports it. | `python`, `node`, `npm`, `pip`, `curl`, package command lines, and destination domains |
| Non developer devices | Use WDAC, AppLocker, or Intune application control to restrict unapproved runtimes and local tools. Do not deploy a blanket Python or Node block to developer populations without an exception and testing model. | Runtime execution on devices outside the approved developer group |
| Dependency risk | Require package provenance, code review, and vulnerability or secret scanning for approved automation. Treat packages that introduce AI clients, agent frameworks, or MCP clients as a review event. | New package processes, newly observed destinations, and configuration file creation |

Intune manages device configuration and application deployment, but it does not by itself enforce PyPI or npm registry policy. Pair device management with package source policy, network egress controls, and developer governance.

### AI API Egress And Workload Ownership

| Decision | Recommended implementation | What to review in the workbook |
| --- | --- | --- |
| Approved API use | Allow only documented AI API destinations for the approved workload and device group. Record service owner, application, data classification, authentication method, and allowed domains. | Process to destination mapping, account, device, request volume, and first seen time |
| Unapproved API use | Begin with audit or warn where possible, then block exact domains through custom indicators, SWG, proxy, firewall, or DNS policy after validating business impact. | Domain, subdomain, parent process, command line, and repeated connections |
| Service exceptions | Scope exceptions to the smallest practical device or user group and set an expiry. Revalidate when the provider adds new endpoints or the application changes. | Exception register compared with workbook destinations and access volume |

Use custom URL and domain indicators for exact AI destinations. Web content filtering is category based and does not provide a dedicated AI category or complete provider coverage.

### API Keys, Tokens, And Secrets

| Decision | Recommended implementation | What to review in the workbook |
| --- | --- | --- |
| Secret storage | Move approved API keys from scripts, local configuration, and repositories into Key Vault or another approved secret store. Use managed identity where the workload supports it. | Command lines, configuration files, repository findings, and workload owner |
| Secret detection | Enable GitHub secret scanning and push protection where available. Use code scanning, Defender for DevOps, and repository review to identify exposed AI credentials. | Secret alerts, repository remediation, key rotation, and endpoint history |
| Incident response | Revoke and rotate exposed keys, identify the workload that used them, review all destinations reached, and add a prevention rule before closing the incident. | Key rotation record, API destination history, process evidence, and owner confirmation |

Never place a production AI API key in a command line, a configuration file committed to source control, a chat prompt, or an exception ticket. The workbook can identify process and destination context, but it is not a secret vault or a complete code scanning service.

### Azure AI Resource Governance

| Decision | Recommended implementation | What to review in the workbook |
| --- | --- | --- |
| Resource creation | Use Azure RBAC and Azure Policy to limit who can create AI resources, model deployments, private endpoints, and credentials. Scope creation to approved subscriptions, regions, and resource groups. | Azure activity logs, policy compliance, resource owner, and approval record |
| Model deployment | Require an approved model catalog, workload owner, data classification, and network design before deploying a model. Prefer managed identity and private networking where the architecture supports them. | Deployment records, role assignments, network configuration, and Key Vault access |
| Ongoing review | Review resource inventory, role assignments, quotas, endpoint exposure, and secret rotation on a defined cadence. | Azure Policy results, resource graph inventory, activity logs, and exception register |

### Enforcement Sequence

1. Baseline automation with the workbook and process logging.
2. Place PowerShell and application control policies into audit mode for a representative pilot group.
3. Define approved registries, API destinations, workload owners, and secret storage requirements.
4. Convert validated audit findings into scoped allow rules, blocks, and documented exceptions.
5. Review blocked events and developer impact before extending enforcement to additional device groups.

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

## Control Boundaries

No single E5 control blocks every AI path. Use layered controls: destination enforcement limits where users can connect, data protection limits what can leave the device, application control limits what can execute, and identity controls limit which devices and users can use protected services. Keep the workbook in the loop as the measurement and investigation surface for each control change.

## Official References

* [Prevent data leak to shadow AI: block sensitive data going to sanctioned AI apps](https://learn.microsoft.com/purview/deploymentmodels/depmod-data-leak-shadow-ai-step3)
* [Web content filtering in Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/web-content-filtering)
* [Web protection in Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/web-protection-overview)
* [Diagnose Paste to supported browsers in Endpoint DLP](https://learn.microsoft.com/troubleshoot/microsoft-365/purview/data-loss-prevention/diagnose-paste-to-supported-browser-issues)