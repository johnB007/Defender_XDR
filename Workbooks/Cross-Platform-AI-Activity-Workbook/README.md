# Cross Platform AI Activity Workbook

A Microsoft Sentinel workbook for investigating artificial intelligence activity across MDE onboarded Windows, macOS, and Linux devices. The workbook includes approved Microsoft 365 Copilot activity and nonapproved artificial intelligence activity in the same investigation surface.

## What This Package Contains

| File | Purpose |
| --- | --- |
| `Cross-Platform-AI-Activity.workbook` | Importable Microsoft Sentinel workbook definition |
| `Build-CrossPlatformAIActivity.ps1` | Rebuilds the workbook from the current query and catalog logic |
| `AI-Domain-Catalog.json` | MIT licensed v2fly catalog snapshot with provider and domain metadata |
| `Invoke-AIWorkbookTelemetry.ps1` | Generates bounded test telemetry on authorized Windows test devices |

## Scope And Guardrails

The workbook identifies activity that matches known artificial intelligence domains, browser traffic, process names, script activity, local model artifacts, agent tools, MCP activity, sensitive file indicators, and existing Defender alerts.

A network match is an investigation signal. It is not proof that a user entered a prompt, received an answer, or transferred a specific document. `CloudAppEvents` paste records show that a paste action was observed, but the Sentinel event does not expose the literal clipboard text. Evidence collection in Microsoft Purview may provide a separate evidence path when it was enabled before the event.

Microsoft 365 Copilot is represented as the approved service in the workbook. Approval is a policy classification in this workbook, not a claim that every event is risk free.

## Before You Import

1. Onboard the device to Microsoft Defender for Endpoint.
2. Confirm that the required Defender and Sentinel data connectors are enabled.
3. Confirm that the operator can read the target Log Analytics workspace.
4. Confirm that the workspace contains the MDE tables used by the selected panels.
5. Review the domain catalog snapshot and refresh it through the generator before publishing a long lived copy.
6. Use the telemetry script only on authorized test devices. Do not run it on a personal or production workstation.

### Main Tables

| Table | Used for |
| --- | --- |
| `DeviceNetworkEvents` | Remote URLs, IP addresses, processes, devices, and initiating accounts |
| `DeviceProcessEvents` | Process creation, command lines, process owners, and agent or MCP evidence |
| `DeviceFileEvents` | Installer, model, extension, sensitive file, and local AI artifacts |
| `DeviceRegistryEvents` | Local configuration and persistence indicators |
| `CloudAppEvents` | Cloud application activity, browser paste records, policy metadata, and sensitive information classifications |
| `AlertInfo` | Existing Defender alerts and severity |
| `AlertEvidence` | Device and evidence correlation for existing alerts |

## Filters

The workbook provides global time, device, account, and tab controls.

| Control | Enter |
| --- | --- |
| Time range | The period to investigate |
| Device Name | The MDE `DeviceName`, such as `workstation-01`, `server-01.example.test`, or `linux-host-01` |
| Account | The account UPN or account name, such as `user@contoso.com` or `Administrator` |
| Tab | The investigation view to display |

The device and account filters are text filters. They are not identity pickers. Use the exact value shown in the result tables. MDE `DeviceId`, Entra `AadDeviceId`, Azure resource identifiers, and Entra `AccountObjectId` are shown in identity detail panels where available.

## Tab Guide

### 1. AI Activity Overview

**Purpose:** Start with the broadest view of artificial intelligence activity across the selected time range.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Top 5 AI Applications by Distinct Users | Applications ranked by distinct observed users | Identify the services with the widest user reach |
| Top 100 AI Application Results: Users, Devices, Events, and IP Addresses | Detailed application results with affected identities and infrastructure | Pivot from a service to users, devices, events, and addresses |
| Daily Unauthorized AI Events Compared with Approved M365 Copilot Events | Daily comparison of nonapproved activity and approved Copilot activity | Identify spikes, policy changes, or unusual periods |
| Unauthorized AI Events by Access Method | Browser, script, process, API, or related access categories | Decide whether the next investigation step belongs in browser, process, or network telemetry |

**Review sequence:** Start with the top application chart, select the highest volume service, then use the detailed results to identify the accounts and devices. Move to Unauthorized or Web Tracking for identity and domain detail.

### 2. Unauthorized AI

**Purpose:** Focus on services that are not in the approved Microsoft 365 Copilot set.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Top 5 Accounts by Unauthorized AI Network Events | Accounts associated with nonapproved network events | Prioritize user review |
| Top 5 Devices by Unauthorized AI Network Events | Devices with the highest nonapproved network volume | Prioritize device timeline review |
| Top 5 Nonapproved AI Services by Network Events | Services and domains with the most network events | Identify the main exposure destinations |
| Unauthorized AI Access Records by Account, Device, Service, and Process | Detailed access records joining user, device, service, process, and URL context | Build an investigation timeline |
| Nonapproved Provider and Domain Governance Inventory | Provider, domain, approval state, activity, users, devices, and response context | Review domain classification and governance coverage |

**Important interpretation:** A network event can represent a browser request, application request, background request, or service dependency. Review the initiating process and user fields before assigning intent.

### 3. Sensitive File and AI Correlation

**Purpose:** Identify cases where sensitive file activity is followed by artificial intelligence access.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Correlated Sensitive File Indicators by Risk Level | Risk scored file activity correlated with later AI access | Start with high risk correlations |
| Top 5 AI Services after Sensitive File Activity | Services contacted after a sensitive file event | Identify possible transfer destinations |
| Top 5 Accounts with File to AI Correlations | Accounts connected to both file activity and AI access | Prioritize account review |
| Top 5 Devices with File to AI Correlations | Devices connected to both activities | Pivot to device timeline and containment decisions |
| Sensitive File and Subsequent AI Access Evidence | Detailed file, account, device, service, timing, and response fields | Preserve evidence and document the correlation |

**Review sequence:** Confirm the file event first, check the correlation time window, verify the initiating account and process, then review whether the destination was approved. Do not infer that the file content was uploaded unless an upload event or Purview evidence confirms it.

### 4. Automation and API

**Purpose:** Find artificial intelligence access initiated by scripts, command shells, automation, or API clients.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Top 5 Script and Command Processes Calling AI Services | Script and command processes associated with AI network events | Identify automation tools and interpreters |
| Top 5 Accounts Running Scripted AI Access | Accounts launching scripted access | Assign ownership and review authorization |
| Top 5 Devices Running Scripted AI Access | Devices with scripted AI activity | Scope the host investigation |
| Script Owner, Process, AI Service, Command Context, and Response | Detailed process owner, command line, service, endpoint, and response guidance | Capture command context and decide remediation |

**Command line caution:** Command lines can contain secrets, tokens, file paths, or prompt material. Limit access to authorized investigators and redact sensitive values before sharing screenshots or tickets.

### 5. Local AI

**Purpose:** Identify local artificial intelligence tools, installers, model files, and local web interfaces that may not create obvious cloud service activity.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Local AI Evidence by Execution, Installer, or Model File | Local tool execution, installer artifacts, model files, and related activity | Find local AI presence even without remote AI traffic |
| Top 5 Devices with Local AI Artifacts or Execution | Devices with the most local AI evidence | Prioritize host review |
| Top 5 Accounts Creating or Running Local AI | Accounts associated with local AI artifacts or execution | Assign ownership |
| Local AI Tool, Model, Installer, Owner, and Response Evidence | Detailed tool, model, installer, owner, and response fields | Document the local AI investigation |

**Important interpretation:** File presence alone does not prove execution. Use process events, execution timestamps, hashes, and user context to distinguish an installer download from a running local model.

### 6. Agents and MCP

**Purpose:** Identify agent frameworks, agent tools, MCP clients, MCP server commands, instruction files, and configuration evidence.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Top 5 Detected Agent Tools and MCP Invocations | Tools and MCP related activity ranked by event volume | Identify the most common agent paths |
| Top 5 Accounts Running Agents or MCP Commands | Accounts associated with agent or MCP activity | Assign ownership and authorization review |
| Top 5 Devices Running Agents or MCP Commands | Devices associated with agent or MCP activity | Scope device investigation |
| Agent Tool Ownership, First Seen, Last Seen, and Commands | Ownership, timing, command, and tool context | Build a repeat activity timeline |
| Agent Executable and MCP Command Evidence | Executable, command line, process owner, and endpoint evidence | Determine how the tool was launched |
| Agent Instructions, MCP Configuration, and Command Evidence | Instruction files, configuration files, and command evidence | Review tool permissions and connected services |

**Important interpretation:** A request to an MCP URL is not by itself proof of a successful MCP session. Confirm the initiating process, account, command, authentication result, and server endpoint where available.

### 7. Investigation

**Purpose:** Consolidate findings that need analyst attention and correlate them with existing Defender alerts.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Prioritized AI Findings Requiring Analyst Review | Risk scored findings with evidence and recommended action | Establish the investigation queue |
| Existing Defender Alerts by Severity on Devices with AI Evidence | Existing alerts on devices that also show AI evidence | Identify cases with related security context |
| Top 5 AI Evidence Devices by Existing Defender Alert Count | Devices ranked by alert count within the AI evidence set | Focus on devices with multiple signals |
| Existing Defender Alerts on AI Evidence Devices, Correlation Only | Alert details correlated to AI evidence devices | Avoid treating correlation as causation |

**Review sequence:** Review the highest priority finding, open the related device and account evidence, compare event timing with existing alerts, and record whether the relationship is confirmed, possible, or unrelated.

### 8. Web Tracking

**Purpose:** Provide the broadest approved versus nonapproved application inventory and corroborate browser paste audit records.

**Panels:**

| Panel | What it shows | Analyst use |
| --- | --- | --- |
| Primary AI Application Governance Inventory: Approval, Activity, Users, IP Addresses, Devices, and Action | Main service inventory with approval and activity context | Review governance posture |
| Top 5 Accounts across Approved and Nonapproved AI Events | Users across both Copilot and nonapproved activity | Find the highest total AI activity users |
| Top 5 Devices across Approved and Nonapproved AI Events | Devices across both activity classes | Compare device level behavior |
| Top 5 Browsers, Scripts, and Applications Reaching AI Services | Client applications reaching AI services | Distinguish browser, script, and application access |
| AI Application Users, Devices, Domains, IP Addresses, Processes, and Approval Status | Detailed user, device, domain, address, process, and approval view | Pivot across the full evidence chain |
| Corroborating Browser Paste and M365 Copilot Audit Evidence | Paste actions, destination, policy, rule, sensitive information classifications, and evidence references | Corroborate browser paste activity |

**Paste evidence boundary:** The current Sentinel event records the paste action and related metadata. It does not expose the literal clipboard text. Purview evidence collection is a separate evidence source and must have been configured before the event.

## Test Telemetry

The test script can create bounded synthetic files, process markers, browser traffic, MCP markers, and network requests on an authorized Windows test device.

Example:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Invoke-AIWorkbookTelemetry.ps1 `
    -Generate `
    -BrowserTraffic `
    -McpTest `
    -KeepArtifacts
```

The script opens visible browser tabs and creates synthetic artifacts. It does not paste clipboard content. Use only an authorized test destination for any upload test. Wait up to 15 minutes for MDE ingestion, then filter the workbook to the exact MDE device name.

Linux and macOS note: the Windows telemetry script is not a cross platform agent. On Linux, use the MDE supported sensor and separate controlled network and process tests. Azure Arc inventory alone does not populate MDE process or network tables.

## Publish To Azure Commercial

### Manual import

1. Open the Microsoft Sentinel workspace in the Azure commercial portal.
2. Open **Workbooks**.
3. Select **Create** or **Edit** and choose the advanced editor.
4. Open `Cross-Platform-AI-Activity.workbook` in a text editor.
5. Paste the workbook JSON into the advanced editor.
6. Select the target Log Analytics workspace.
7. Save the workbook with a controlled name and description.
8. Open the workbook and validate every tab with a known lab device.

Commercial portal:

[Open Azure commercial portal](https://portal.azure.com/)

### Publication checklist

| Check | Expected result |
| --- | --- |
| Workspace selected | The workbook points to the intended Sentinel workspace |
| Time filter | Queries return data in the selected period |
| Device filter | A known MDE device name returns expected rows |
| Account filter | A known UPN or account name narrows results |
| M365 Copilot | Approved activity appears in approved views |
| Nonapproved services | Domain matches appear in unauthorized views when telemetry exists |
| Empty panels | Empty results are explained by missing data or scope, not malformed JSON |
| Permissions | Analysts can view the workbook and workspace data |

### Commercial publish button placeholder

A direct **Deploy to Azure** button requires a versioned ARM or Bicep deployment template that creates the `microsoft.insights/workbooks` resource and embeds the workbook JSON. This repository currently publishes the importable workbook JSON. Add the final template URL here after the infrastructure template is approved:

`[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](REPLACE_WITH_COMMERCIAL_TEMPLATE_URL)`

## Publish To Azure Government

Azure Government requires a government cloud portal and government cloud resource context. Do not use a commercial portal link for a government tenant.

### Manual import

1. Open the Microsoft Sentinel workspace in the Azure Government portal.
2. Open **Workbooks**.
3. Select **Create** or **Edit** and choose the advanced editor.
4. Paste the contents of `Cross-Platform-AI-Activity.workbook`.
5. Select the government Log Analytics workspace.
6. Save the workbook with a government environment name.
7. Validate the workbook using government tenant data and government cloud endpoints.
8. Confirm that the domain catalog and any external links meet the organization’s policy.

Government portal:

[Open Azure Government portal](https://portal.azure.us/)

### Government publication checklist

| Check | Expected result |
| --- | --- |
| Government workspace | The workbook is saved in the intended Azure Government Sentinel workspace |
| Cloud boundary | No commercial tenant resource ID or commercial workspace ID is embedded |
| Data connectors | Required Defender and Sentinel connectors are available in the tenant |
| External catalog review | The MIT licensed catalog source is approved for the environment |
| Identity review | Government tenant UPN and device values are used in filters |
| Evidence handling | Screenshots and exported results follow government data handling rules |
| Analyst validation | Every tab is tested with controlled government tenant telemetry |

### Government publish button placeholder

A direct **Deploy to Azure Government** button requires a government compatible ARM or Bicep template and an approved government template URL. Add the final URL here after the infrastructure template is approved:

`[![Deploy to Azure Government](https://aka.ms/deploytoazurebutton)](REPLACE_WITH_GOVERNMENT_TEMPLATE_URL)`

## Updating The Catalog

The catalog snapshot records the source repository, MIT license, retrieval time, root lists, supplements, and entries. To refresh it:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Build-CrossPlatformAIActivity.ps1
```

Review the generated catalog and workbook diff before publication. Preserve the source and retrieval metadata. Do not treat the catalog as a block list or as a statement that every listed domain is malicious.

## GitHub Publication

From the repository root:

```powershell
git status
git add Defender_XDR/Workbooks/Cross-Platform-AI-Activity-Workbook/Cross-Platform-AI-Activity.workbook
git add Defender_XDR/Workbooks/Cross-Platform-AI-Activity-Workbook/Build-CrossPlatformAIActivity.ps1
git add Defender_XDR/Workbooks/Cross-Platform-AI-Activity-Workbook/AI-Domain-Catalog.json
git add Defender_XDR/Workbooks/Cross-Platform-AI-Activity-Workbook/Invoke-AIWorkbookTelemetry.ps1
git add Defender_XDR/Workbooks/Cross-Platform-AI-Activity-Workbook/README.md
git commit -m "Document cross platform AI activity workbook"
git push origin main
```

Review `git status` before committing. Do not add generated HTML preview files. Do not commit screenshots containing personal data or secrets.

## License And Attribution

The workbook source and scripts remain subject to the repository license. The AI domain catalog includes data derived from the MIT licensed [v2fly domain list community](https://github.com/v2fly/domain-list-community). The catalog is a detection aid and does not endorse blocking, proxying, or restricting any listed domain.
