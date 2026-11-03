# Oscar lab deployment plan

Status: Blocked pending on premises package acquisition

Generated: 2026-11-02

Validation applies only to the disabled mock bootstrap candidate, not real Oscar collection or operational readiness.

The first actual disabled deployment failed with InvalidSecureDataConfiguration on the Compose action Parse_status. ARM validation and what if had accepted this revision, but the Logic Apps service rejected its explicit secure outputs setting. ResourceNotFound was independently confirmed afterward: no Oscar workflow or new workflow identity exists yet, and no parent permission grants were made. Correct action specific secure input/output semantics and revalidate the changed hash before retrying.

The generated action security settings have now been corrected according to Microsoft's supported operation table. Compose, Parse JSON and Response secure inputs also hide their own outputs; their unsupported explicit secure outputs flags are removed, not their protection. Supported downstream actions remain explicitly secured. The corrected revision passed the core Azure validation helper, 31 static checks and 29 model/host checks. Formal validation remains incomplete. No second deployment was attempted.

The customer's acceptance scope changed to on premises workstations and servers. The fixed AVD mock candidate is paused, not a customer ready configuration. Prefer the verified physical 324 workstation over DC007, a domain controller whose hypervisor host location remains unverified. Package access, the revised device contract and a real LR pilot must be established before another release validation.

## 1. Project overview

Prepare a minimal cost Oscar proof of concept in the existing SOC-Central lab. Use an incident playbook for dispatch, completion comments and approved email. Host the intact tool ZIP in private Blob. Run without RAM on one confirmed lab device, retrieve results through MDE Live Response first, and offer direct Blob upload of the completed parts as an explicit alternative.

The requested outcome is a demonstrated workflow, not merely a deployed template. Do not mark the report fully tested until real collection, all part transfers, integrity verification, incident comments and approved email delivery have evidence.

## 2. Requirements

| Attribute | Value |
|---|---|
| Classification | Lab proof of concept |
| Scale | One authorized device initially |
| Budget | Minimize incremental Azure resources and executed actions |
| Target | Existing SOC-Central resource group and workspace in East US |
| Subscription | Previously verified lab subscription, reverified by read only preflight on 2026-11-02 |
| Endpoint scope | On premises workstations and servers. Prefer physical 324 for acceptance. Earlier AVD prerequisite testing does not meet that requirement. |
| Results | Local LR retrieval first; optional Blob evidence upload and local analyst download |
| Retention | User approved a 30 day deletion policy restricted to Oscar results, excluding the package and existing backups; preserve evidence holds and account protections |
| Publication | Local files only; no commit or push |

## 3. Components detected

The Oscar folder contains the original package, supplied evidence, decision HTML, architecture exports and a local mock deployment candidate. The candidate contains a disabled Consumption workflow, bounded PS5.1 mock worker, optional existing file uploader, admin helper and integrated notification. Real collection remains deliberately blocked.

Existing lab resources include private Blob accounts and Consumption incident playbook patterns. Preflight found connected Sentinel and mail connectors. No MDE or Blob connection was found in the target resource group.

## 4. Recipe selection

Recipe: AZCLI. The actual deployment uses the reviewed ARM JSON for one Consumption workflow and its approved workspace scoped Sentinel role. Keep solution files in the supplied Oscar folder. This repository plan exists for Azure workflow bookkeeping only.

The shared validation helper requires Bicep compilation. A local validation only `validate.bicep` module wrapper references the exact ARM JSON and lab parameter file. It does not replace the actual deployment template or select additional runtime infrastructure.

The earlier Standard hosting, dedicated Functions broker/verifier and Table job store are not selected additions. The existing AVD identity and subnet supported a prerequisite probe only. They are not the selected on premises endpoint authentication path. Do not remove required security controls to reduce cost.

## 5. Architecture and blockers

1. Preferred control plane is one manually invoked Consumption incident playbook. Reuse an existing connection only after confirming its authorization and owner.
2. The package remains intact in private Blob. Do not substitute the commercial Defender portal library size for the Government requirement.
3. Use a reviewed small tenant library script and an approved bounded local worker. Verify the current CLI before executing Oscar.
4. Local results and collection status are separate from retrieval status. Each actual part must fit LR limits and complete transfer successfully.
5. Optional Blob upload reuses the already collected parts and requires authenticated endpoint transfer and verified destination receipt.
6. Email and incident comments carry approved identifiers and actual retrieval location, not archive payloads or credential bearing links.

### Verified blocking evidence

Read only preflight on 2026-11-02 found that all three inspected existing storage accounts disable public network access, anonymous Blob access and shared keys. This workstation resolves their Blob names to public addresses and authenticated container listing was rejected by storage network rules.

Read only network inspection identified AVDLAB-ADMIN01 on the same subnet as the approved dc007backup882d9ca8 Blob endpoint. Private DNS is linked, and no custom DNS or route table was reported. This supports a guest test without new networking but does not prove successful guest DNS, HTTPS or data authorization. The user explicitly approved this AVD and storage reuse.

Current MDE Live Response execution permission, a test incident, free disk space, current Oscar CLI and archive opening behavior remain unverified. A Defender library metadata request succeeded; it is not proof of write or execution permission.

Read only target verification found 324-um-defcon30 Active and Onboarded in MDE, with connected Arc metadata identifying Surface Book 2 hardware. Its existing Arc principal is 7d467c3e-0d17-4f3d-bba9-278683032c8d. Arc uses protected local HIMDS at localhost:40342, not Azure VM IMDS. No package container assignment was found for that principal, and private Blob access from 324 is not proven. Do not transfer the prior AVD role approval to this principal.

The smallest remaining acquisition choices are reuse of the existing Arc identity with separately approved container permission and an existing private route, or administrator prestaging of the intact ZIP using an existing authenticated transfer. Neither has been selected or proven for this pilot. Do not add a broker, identity, public access or reusable endpoint credential implicitly.

The user approved a dedicated Cyber Team distribution group containing only Elliott and admin. It was created through authenticated Exchange Online PowerShell in the verified lab tenant on 2026-11-02. Exact member verification succeeded. The group requires authenticated senders. No test message has been sent.

### Policy constraints

Do not enable public networking, change shared key settings or alter existing workflow behavior implicitly. The user approved container scoped storage permissions.

On 2026-11-02 the user explicitly approved granting the new Oscar playbook managed identity the Defender application role Machine.LiveResponse in the lab tenant. The underlying permission can run Live Response across the tenant; the workflow restricts requests to AVDLAB-ADMIN01 but that restriction does not narrow the application permission. The role has not been assigned. No additional Defender application roles are implicitly approved.

The user separately approved Machine.ReadWrite.All for that same identity after Microsoft documentation confirmed it is required for automated machine action status and LR result link retrieval. Its broad lab tenant device information scope was explained. Neither role has been assigned.

The user also explicitly approved Microsoft Sentinel Responder for that same identity at the SOC-Central workspace only. The generated role provisioning and static checks are being updated before final validation. No subscription scoped grant is approved.

Subscription policy assignments were read on 2026-11-02. The returned assignments cover Defender provisioning, data protection and Guest Configuration. ARM validation and what if must still detect applicable deployment restrictions; this is not a claim that no restrictions exist.

## 6. Provisioning inventory and limits

The approved inventory is one Consumption workflow with a managed identity and only the required connection/role configuration, plus two new Oscar containers in existing storage. Reuse existing approved Sentinel and mail connections if their authentication verifies. No new storage account, VM, premium hosting, private endpoint or dedicated monitor is selected.

| Resource | Approved addition | Capacity evidence |
|---|---|---|
| Microsoft.Logic/workflows | 1 Consumption workflow | Four existing East US workflows in the lab subscription; total after deployment is five. Official documented limit is 1,000. The quota CLI returned BadRequest for Microsoft.Logic, so documented limits and actual resource count were used. |
| Microsoft.Storage/storageAccounts | 0 | Existing approved account only |
| Blob containers | 2 | Separate oscar-packages and oscar-results, without replacing existing containers |
| Microsoft.Web/connections | Reuse preferred | Exact connector resources and role scopes will be recorded by generated template validation |
| VM, private endpoint and dedicated compute | 0 | Existing AVD and private endpoint reused |

### Simple deployment and SOC operation

The user requires easy deployment and daily operation for SOC analysts with limited IT experience. Separate administrator setup from analyst use.

Create exactly one new system assigned managed identity, attached to the new Consumption playbook. Reuse approved Sentinel and mail connections. For 324, its existing Arc identity is an acquisition candidate, not an already authorized data reader. Administrator prestaging remains an alternative for non Arc endpoints. Do not introduce new app registrations, separate user assigned identities or service accounts for analysts. This does not merge the endpoint and playbook trust boundaries or share credentials between them.

An administrator handles initial API consent, scoped storage roles, package staging, signing prerequisites and connection authorization through the deployment package. These are not daily analyst tasks. Setup must identify unresolved prerequisites instead of claiming a completely automatic deployment.

The analyst guide must use the real supported Sentinel incident playbook entry point, with collection without RAM as the pilot default. Explain device selection from the actual incident host data; reject absent or ambiguous targets rather than silently choosing a device. Show where to see status, how to retrieve every original archive part and how to request the optional existing file Blob transfer.

Reusing the AVD identity makes the Azure lab simpler. An arbitrary Government or on premises endpoint does not automatically have that identity or private route. Its authenticated Blob acquisition path remains a separate prerequisite; never copy the playbook credential onto the endpoint or weaken access controls to claim universal simplicity.

### Initial cost evidence

Public East US retail rates were fetched from prices.azure.com on 2026-11-02. Consumption builtin actions cost USD 0.000025 each after any applicable free tier; standard connector actions cost USD 0.000125 each. Actual bill depends on executed actions, retries, polling and retained run history. No fixed Standard hosting plan is selected.

General Block Blob v2 Hot LRS tier zero data capacity was USD 0.0208 per reported GB per month. Retaining the observed roughly 2.92 GB archive for a month is approximately six cents in capacity alone under that SKU. This is an illustrative rate, not a total deployment quote or verification of the selected account SKU. Transactions, download egress, Defender for Storage, soft deletion, versions and existing VM/network charges remain separate.

Blob lifecycle policies themselves have no policy fee. Deletion eligibility after 30 days is not an exact deletion time; background processing and retained soft deleted data or versions can extend billed retention. Preserve existing protections rather than disabling them to meet an estimate.

## 7. Execution checklist

1. Completed: read only lab identity, workspace, existing workflow pattern and workstation storage preflight.
2. Completed: identify AVDLAB-ADMIN01 and inspect its existing identity and private endpoint subnet.
3. In progress: guest package/results access and test incident. Approved Cyber Team mail group was created and verified.
4. Completed: user approved AVD, existing storage, scoped permissions and results only 30 day retention. Workflow count, provider quota fallback and initial public unit prices recorded. Machine.LiveResponse approval recorded after explaining its tenant wide scope; assignment is pending.
5. Completed for the disabled mock candidate: one workflow template, standalone PS5.1 LR script, admin helper, synthetic fixtures and integrated polished notification. Real collection remains explicitly blocked.
6. Partially complete for the corrected AVD mock only: core Azure helper, 31 static checks and 29 model/host checks passed. Formal validation and the revised on premises contract remain pending.
7. Blocked: select and prove authenticated package acquisition for 324, revise its device contract, complete fresh validation, then deploy through azure-deploy with only approved permissions.
8. Pending: perform a synthetic device smoke test before the authorized Oscar test.
9. Pending: collect without RAM, retrieve every part, compare hashes and measure actual duration.
10. Pending: test optional existing file Blob upload, approved email, incident comments and failure handling.
11. Pending: update the decision report and presentation with measured results and remaining limitations.

## 7. Validation proof

The corrected disabled mock passed the core Azure validation helper. Formal validation is incomplete, and the AVD target does not satisfy the revised acceptance scope. Status is not Validated.

## 8. Files to generate

Implementation artifacts live under the user supplied OscarForensicTool folder. The disabled mock deployment template, gated worker, synthetic fixtures, manifest contract, validation evidence and operating instructions exist. Real collection and the on premises package path remain unverified.

This plan has a rendered sibling HTML companion. No generated HTML is to be staged or committed.

## 9. Next step

Select and prove the on premises acquisition path for 324 before revising and validating the target contract. Keep the fixed AVD mock paused. Real Oscar collection remains blocked and cannot be enabled by changing a parameter.

## Validation scope and local evidence

Validation checklist, not a declaration of completed formal validation:

1. Core AZCLI validation: CLI and authenticated lab context, build the validation wrapper, validate the exact candidate against SOC-Central, and inspect what if for unapproved modifications or deletion.
2. Container build: not applicable; this candidate deploys no container or application image.
3. Azure Policy validation: review applicable policy and Azure validation results without relaxing existing controls.
4. Role verification: cross check the one new workflow identity and the approved workspace scoped Sentinel role, plus the explicit post deployment Defender application role contract. Endpoint and notification execution stay disabled until runtime permissions are verified.
5. Record the exact validated template hash and scope. Disabled mock validation does not prove real collection or Government support.

The current validation scope is a disabled mock lab workflow only. It is not approval or validation of real Oscar execution, customer deployment or Government support.

Artifact folder: `C:\Users\jobarbar\OneDrive - Microsoft\Documents\Contracts\_DoDIG\OscarForensicTool\Deployment`.

Static package inspection confirmed the original ZIP and executable hashes match the recorded bytes. The executable reports NotSigned and has no signer thumbprint. This work did not execute it; the temporary extracted inspection copy was removed. The user approved the exact pinned package for commercial lab testing only. Customer trust and licensing approval remain separate. No script signing or execution protection was weakened.

Current template SHA256: `2C587A567656551EDE8C30CABBDB06EE1C8CF90D653C984114E34842FBFF0A03`. This revision includes the approved workspace scoped Sentinel role and corrected action specific secure settings. Earlier validation proof below belongs to the failed B861 revision until the fresh validation completes.

Local evidence: the parent reran 10 PS5.1 fixture checks, 21 static template checks, 29 synthetic model/host gate checks and the read only admin preflight successfully against this final revision. LR parser, analyzer and interactive call scan passed without executing the script. Parent email checks passed eight expression/content cases and 18 Edge viewport/state cases. These are local mocked tests, not endpoint or connector proof.

## Role Assignment Verification

Status: Verified for the disabled bootstrap code only.

Exactly one workflow system assigned identity is created. Its Sentinel Responder role references the actual workflow principal and is scoped to the exact SOC-Central workspace. There are no additional app registrations, user assigned identities or analyst accounts.

Machine.LiveResponse and Machine.ReadWrite.All are separately approved post deployment application role grants to that same identity. The bootstrap keeps dispatch and notifications off until those grants and runtime prerequisites verify. Existing AVD Blob roles are approved at the separate Oscar container scopes and remain unapplied.

## 7. Validation Proof

Commands completed on 2026-11-02:

```powershell
$candidate = 'C:\Users\jobarbar\OneDrive - Microsoft\Documents\Contracts\_DoDIG\OscarForensicTool\Deployment'
& 'C:\Users\jobarbar\.agents\skills\azure-validate\references\recipes\scripts\validate-deployment.ps1' -Scope group -ResourceGroup SOC-Central -Subscription '882d9ca8-f61e-4cc8-a081-dc01aab06b8a' -Template (Join-Path $candidate 'validate.bicep')
python (Join-Path $candidate 'Test-Template.py')
python (Join-Path $candidate 'Test-EmailModel.py')
powershell.exe -NoProfile -File (Join-Path $candidate 'Test-OscarLocal.ps1')
powershell.exe -NoProfile -File (Join-Path $candidate 'Invoke-OscarAdminSetup.ps1')
```

Results: core helper OVERALL PASS; static template 21 passed; model/host gate 29 passed; local fixture 10 passed; admin preflight passed without changes.

The shared AZCLI helper passed CLI availability, authenticated subscription, Bicep wrapper build, ARM validation and what if. The wrapper previews three creates because it adds a validation module deployment record. The actual ARM JSON preview was separately inspected: exactly two creates, the workflow and its workspace scoped role, zero modifications and zero deletions. The 297 other resource entries are ignored or unchanged. The actual deployment will use ARM JSON, not the wrapper.

The scoped candidate validation returned no Azure Policy rejection. Previously read subscription assignments and this prospective result do not prove unrelated resources or future Government deployment compliant.

An authorized read only prerequisite probe ran on AVDLAB-ADMIN01 through Azure VM Run Command, not MDE LR. Guest metadata matched the approved VM; Blob DNS resolved to 192.168.0.8; an IMDS storage token was obtained in memory without logging it. Available disk bytes were C: 74935590912, D: 158360727552 and F: 137314795520. The Oscar package container request returned HTTP 403. This proves neither container authorization nor package staging; Oscar roles and containers remain unapplied. No Oscar execution or evidence read occurred.

Release blockers remain: real collector implementation and current version CLI/completion/process containment verification, package trust and licensing verification, guest private storage access, actual LR transfers, actual email/incident updates and customer endpoint authentication outside Azure. Do not transfer disabled mock acceptance to those untested paths.

## Observed Oscar alerts and customer tuning review

On 2 November 2026, SOC-Central telemetry confirmed the user's exact supplied Oscar executable running on 324 at 14:12 UTC. A process identity anchored traversal observed five executable names and eight process instances: Oscar, autorunsc, openfiles, conhost and Edge. No further child remained beyond the checked depth in the available telemetry. This is a user GUI run, not a smoke test of the new LR worker or no RAM command.

Four EDR alerts reference the exact Oscar hash: credential hive access, browser sensitive information in two alerts, and compression of sensitive data. Windows antivirus exclusions do not suppress EDR alerts. No antivirus exclusion, allow indicator, ASR exception, controlled folder access exception or alert tuning rule was applied.

The customer report now contains a review matrix and `Deployment\Oscar-MDE-Review.csv` with observed executable hashes and sanitized location categories. Only narrowly scoped EDR tuning is a review candidate for the authorized Oscar run. The other observed processes remain protected. Hundreds of copied or deleted evidence binaries are not additional executed helpers or an exclusion list.

DeviceEvents also returned 62 AsrAbusedSystemToolAudited records, all IsAudit=true for rule c0033c00-d16d-4114-a5a0-dc9b3a7d2ceb, Block use of copied or impersonated system tools. The referenced paths are in Oscar's autoruns evidence directory. `Deployment\Oscar-ASR-Review.csv` preserves all 62 sanitized referenced file rows and their hashes. They are not proof of 62 process launches, blocking or a need for global exclusions. Validate the customer's actual enforcement mode; any rule specific path exception requires separate legitimate block evidence and approval.

Five AntivirusReport records identify the Oscar hash with WasExecutingWhileDetected=false, but the returned fields do not establish a threat verdict or remediation outcome. A SmartScreenAppWarning was also observed. Protection history and tool trust remain separate review gates. No warning bypass or protection change is part of this work.

Any future tuning requires actual supported hash and device conditions, the selected alert type, an approved run window, a named owner and rollback. Do not accept the tuning wizard's separate file allow list step implicitly. Reinventory the eventual SYSTEM run, inspect prevention events, test nonmatching activity visibility and verify Government portal support separately.
