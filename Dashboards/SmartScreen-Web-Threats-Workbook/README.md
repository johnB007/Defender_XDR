# SmartScreen Web Threats

A Microsoft Sentinel workbook for hunting risky web activity surfaced by Microsoft Defender SmartScreen and Microsoft Defender Web Content Filtering (Network Protection) in `DeviceEvents`. It answers the question: which users are visiting risky or non business categories such as adult, gambling, dating, gaming, or streaming sites, and which of those visits turned into malicious, phishing, or tech scam blocks.

## What this workbook is built around

Microsoft Defender for Endpoint surfaces user web activity through two related signals in `DeviceEvents`:

| Signal | ActionType | What it tells you |
|---|---|---|
| SmartScreen URL warning | `SmartScreenUrlWarning` | The Microsoft SmartScreen reputation service blocked a URL with an `Experience` label of `Malicious`, `Phishing`, `TechScam`, `Untrusted`, `CustomBlockList`, or `CustomPolicy`. |
| SmartScreen App warning | `SmartScreenAppWarning` | A downloaded executable was blocked by SmartScreen App reputation. |
| SmartScreen user override | `SmartScreenUserOverride` | A user clicked through a SmartScreen warning and proceeded to the blocked destination anyway. High-priority follow-up. |
| Network Protection user bypass | `NetworkProtectionUserBypassEvent` | A user bypassed a Network Protection block. Same acknowledged-risk pattern as the SmartScreen override above. |
| Web Content Filter or Network Protection block | `ExploitGuardNetworkProtectionBlocked` | A request was blocked by Network Protection. When Web Content Filtering policy is assigned, `AdditionalFields.ResponseCategory` carries the content category (`Adult content`, `Gambling`, `Dating`, `Gaming`, `Streaming media`, `Liability`, `High bandwidth`, `Leisure`, and so on) and `ResponseCategoryGroup` carries the parent group. |
| Web Content Filter or Network Protection audit | `ExploitGuardNetworkProtectionAudited` | Same shape as the block event but the policy was in audit mode, so the request was logged and allowed. Useful for tuning a policy before flipping it to enforce, and for catching low reputation destinations the user reached even though no block fired. |

The two streams overlap. A user clicks an ad on a non business category site, Network Protection blocks the destination by category, and seconds later SmartScreen flags the next redirect as `Malicious`. This workbook joins both streams to the same `InitiatingProcessAccountUpn` (Entra UPN) so you can see that path in a single grid.

## How to use this workbook

### SOC analysts and threat hunters

1. Start on the Top Users / Domains tab. Sort the user grid by the red MaliciousHits column, then the orange RiskyHits column. Anything red on the left is the first thing to look at.
2. Switch to Risky User Correlation. This tab only lists users who triggered both risky non business category events (Adult, Gambling, Dating, Gaming, Streaming) and malicious, phishing, or tech scam events in the selected window. The MinutesRiskyToMalicious column is a strong indicator of malvertising or drive by activity from low reputation ad networks.
3. Drop the user UPN into the User (Entra UPN) filter at the top of the workbook. Every tab now scopes to that user.
4. Use URL contains to pivot on a domain or keyword (for example `bet365`, `crack`, `stream`, or a suspicious TLD) across all users.
5. The Web Content Filter (Category) tab shows the categorized destination. This is the only place to see whether the site was tagged as Adult, Gambling, Dating, Gaming, Streaming, Liability, or similar.
6. Every event level grid surfaces `InitiatingProcessFileName` and `InitiatingProcessCommandLine` so you can confirm which browser or process triggered the block, such as Edge, Chrome, an Outlook redirector, or a Teams click through.

### Sysadmins and IT operations

* Weekly review of the Top Users / Domains tab to identify repeat offenders and noisy non business destinations to add to your Web Content Filtering policy.
* Onboarding new endpoints. Filter by Device to verify a freshly imaged device is not already triggering reputation hits.
* Policy tuning. When Network Protection or a Custom Block List is in audit mode, the Web Content Filter tab includes the `IsAudit` column so you can see what would be blocked before flipping the policy to enforce.

### Compliance and audit

* Non business browsing on corporate endpoints is a common acceptable use policy and HR finding. The Web Content Filter (Category) tab includes a Risky Category by User and Domain grid that can be exported for that conversation.
* All grids honor the standard Export to CSV and Export to Excel options after running.

## What it shows

A single top level filter row plus eleven tabs.

### Global filters (apply to every tab)

| Filter | Purpose |
|---|---|
| Time Range | 30m, 1h, 4h, 12h, 1d, 3d, 7d, 14d, 30d, 60d, 90d, plus custom range. |
| User (Entra UPN) | Multi select dropdown populated from `InitiatingProcessAccountUpn`. `All` by default. |
| Device | Multi select dropdown populated from `DeviceName`. `All` by default. |
| URL contains | Free text substring matched against `RemoteUrl` using the `has` operator. |

### Tabs

| # | Tab | Purpose |
|---|---|---|
| 1 | Top Users / Domains | Triage landing page. Events by category bar chart, Top 25 domains (hits, users, devices), Top 25 users with colored MaliciousHits (red) and RiskyHits (orange) columns. |
| 2 | Risky User Correlation | Users who triggered both risky non business category events and malicious, phishing, or tech scam SmartScreen events. Includes FirstRisky, FirstMalicious, MinutesRiskyToMalicious, sample URLs from each side, and a full filtered event timeline with a Severity icon column. |
| 3 | All Categories (URL + Files) | Combined `SmartScreenUrlWarning` and `SmartScreenAppWarning` timechart and event grid. Brush select on the chart to drill into a window. |
| 4 | Web Content Filter (Category) | `ExploitGuardNetworkProtectionBlocked` and `ExploitGuardNetworkProtectionAudited` events parsed for `ResponseCategory`, `ResponseCategoryGroup`, and `IsAudit`. Audit rows expose what would have been blocked if the policy were enforced. Includes a dedicated Risky Category by User and Domain summary. |
| 5 | Files (SmartScreenApp) | `SmartScreenAppWarning` only. File download SmartScreen blocks. |
| 6 | TechScam (URL) | SmartScreen `TechScam` experience. |
| 7 | Phishing (URL) | SmartScreen `Phishing` experience. |
| 8 | Untrusted (URL) | SmartScreen `Untrusted` experience. |
| 9 | Malicious (URL) | SmartScreen `Malicious` experience. |
| 10 | Custom Block List (URL) | SmartScreen `CustomBlockList` experience. Your custom indicator hits. |
| 11 | Custom Policy (URL) | SmartScreen `CustomPolicy` experience. Your Web Content Filter policy hits. |
| 12 | User Overrides & Bypasses | `SmartScreenUserOverride` and `NetworkProtectionUserBypassEvent` events. Top users who clicked through a warning, the browser they used (Edge, Chrome, Firefox, Opera, Brave, Other), the categories they overrode, and a full event grid with parsed `Allow`, `IsAudit`, `UserSid`, and `Application` fields. |

### Data sources

* `DeviceEvents` where `ActionType` is `SmartScreenUrlWarning`, `SmartScreenAppWarning`, `SmartScreenUserOverride`, `NetworkProtectionUserBypassEvent`, `ExploitGuardNetworkProtectionBlocked`, or `ExploitGuardNetworkProtectionAudited`.
* `AdditionalFields.Experience` for the SmartScreen verdict label.
* `AdditionalFields.ResponseCategory` and `ResponseCategoryGroup` for the Web Content Filtering category.
* `AdditionalFields.IsAudit` for whether the WCF rule was in audit mode.
* `InitiatingProcessAccountUpn` for the Entra UPN of the user whose process triggered the block.

> Important. The content category (Adult, Gambling, Dating, Gaming, Streaming, and so on) comes only from Web Content Filtering on `ExploitGuardNetworkProtectionBlocked` events. The SmartScreen `Experience` field does not include content type, only verdict. If you do not see categorized data in the Web Content Filter tab, you likely do not have Web Content Filtering enabled or no WCF policy is assigned to your devices. See [Web content filtering in Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/web-content-filtering) to enable it.

## Files in this folder

* `SmartScreen-Web-Threats.json`. Workbook JSON payload for manual import via the Sentinel Advanced Editor.
* `azuredeploy.json`. One click ARM deployment template (Azure Commercial and Azure Government).
* `README.md`. This file.

## How to deploy

Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSmartScreen-Web-Threats-Workbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSmartScreen-Web-Threats-Workbook%2Fazuredeploy.json)

### Deployment inputs

When the deployment blade opens, provide:

* `workspaceName`. The Log Analytics workspace name. Default is `SOC-Central`.
* `workbookDisplayName`. Default is `SmartScreen Web Threats`.
* `workbookId`. Leave the `newGuid()` default to create a new workbook instance.

### Deployment notes

* The workbook is deployed as `kind: shared` and is scoped to the selected Log Analytics workspace.
* To import the workbook manually instead, open Sentinel Workbooks, click Add workbook, click the pencil (Edit) icon, then Advanced Editor, and paste the contents of `SmartScreen-Web-Threats.json`.

### CLI deployment

```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file azuredeploy.json \
  --parameters workspaceName=<your-workspace>
```

## KQL validation

All workbook queries were validated against a live Microsoft Sentinel workspace using `az monitor log-analytics query`. Result summary:

| Query | Result |
|---|---|
| User UPN dropdown | SUCCESS |
| Device dropdown | SUCCESS |
| Overview, Events by Category | SUCCESS |
| Overview, Top 25 Domains | SUCCESS |
| Overview, Top 25 Users | SUCCESS |
| Risky User Correlation grid | SUCCESS |
| Risky User Correlation timeline | SUCCESS |
| All Categories chart | SUCCESS |
| Web Content Filter chart | SUCCESS |
| Web Content Filter grid | SUCCESS |
| Risky Category by User and Domain | SUCCESS |
| Files (SmartScreenApp) grid | SUCCESS |
| Malicious (URL) grid | SUCCESS |

## License

MIT, same as the parent [Defender_XDR](https://github.com/johnB007/Defender_XDR) repo.
