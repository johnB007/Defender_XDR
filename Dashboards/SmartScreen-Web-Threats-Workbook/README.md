# SmartScreen Web Threats

A Microsoft Sentinel workbook for hunting risky web activity surfaced by **Microsoft Defender SmartScreen** and **Microsoft Defender Web Content Filtering (Network Protection)** in `DeviceEvents`. Built for SOC analysts who need to answer the question: *"Which users are going to bad websites, adult sites, or gambling/dating sites — and which of those visits turned into malicious/phishing/techscam blocks?"*

---

## What This Workbook Is Built Around

Microsoft Defender for Endpoint surfaces user web activity through two complementary signals in `DeviceEvents`:

| Signal | `ActionType` | What It Tells You |
|---|---|---|
| **SmartScreen URL warning** | `SmartScreenUrlWarning` | The Microsoft SmartScreen reputation service blocked a URL with an `Experience` label of `Malicious`, `Phishing`, `TechScam`, `Untrusted`, `CustomBlockList`, or `CustomPolicy`. |
| **SmartScreen App warning** | `SmartScreenAppWarning` | A downloaded executable was blocked by SmartScreen App reputation. |
| **Web Content Filter / Network Protection block** | `ExploitGuardNetworkProtectionBlocked` | A request was blocked by Network Protection. When Web Content Filtering policy is assigned, `AdditionalFields.ResponseCategory` carries the **content category** (`Adult content`, `Pornography`, `Nudity`, `Gambling`, `Dating`, `Liability`, `Hate`, etc.) and `ResponseCategoryGroup` carries the parent group. |

The two streams overlap: a user clicks an ad on an adult site → Network Protection blocks the destination as `Adult content` → seconds later SmartScreen flags the next redirect as `Malicious`. This workbook **stitches both streams to the same `InitiatingProcessAccountUpn` (Entra UPN)** so you can see that path in a single grid.

---

## How To Use This Workbook

### SOC Analysts and Threat Hunters

1. Start on the **Top Users / Domains** tab. Sort the user grid by the red **MaliciousHits** column, then the orange **AdultHits** column. Anything red on the left is your hottest lead.
2. Switch to **Risky User Correlation**. This tab only lists users who triggered **both** adult/gambling/dating *and* malicious/phishing/techscam events in the selected window. The **MinutesAdultToMalicious** column is a strong indicator of malvertising or drive-by from the adult/gambling ecosystem.
3. Drop the user's UPN into the **User (Entra UPN)** filter at the top of the workbook. Every tab now scopes to that user.
4. Use **URL contains** to pivot on a domain or keyword (e.g. `xvideos`, `bet365`, `crack`, a suspicious TLD) across all users.
5. The **Web Content Filter (Adult/Category)** tab shows the categorized destination — this is the only place to see whether the site was tagged *Adult*, *Pornography*, *Nudity*, *Gambling*, *Dating*, *Liability*, etc.
6. Every event-level grid surfaces `InitiatingProcessFileName` and `InitiatingProcessCommandLine` so you can confirm which **browser or process** triggered the block (Edge, Chrome, Outlook redirector, Teams click-through, etc.).

### Sysadmins and IT Operations

- **Weekly review** of the *Top Users / Domains* tab to identify repeat offenders and noisy adult/gambling destinations to add to your Web Content Filtering policy.
- **Onboarding new endpoints**: filter by *Device* to verify a freshly imaged device isn't already triggering reputation hits.
- **Policy tuning**: when Network Protection or a Custom Block List is in *audit* mode, the **Web Content Filter** tab includes the `IsAudit` column so you can see what *would* be blocked before flipping the policy to enforce.

### Compliance and Audit

- Adult / NSFW / Gambling browsing on corporate endpoints is a common acceptable-use-policy and HR finding. The *Web Content Filter (Adult/Category)* tab's **Adult / NSFW / Gambling — by User & Domain** grid is the system-of-record artifact for that conversation.
- All grids honor the standard *Export to CSV* / *Export to Excel* affordances after running.

---

## What It Shows

A single top-level filter row plus **eleven tabs**.

### Global Filters (apply to every tab)

| Filter | Purpose |
|---|---|
| **Time Range** | `30m, 1h, 4h, 12h, 1d, 3d, 7d, 14d, 30d, 60d, 90d`, plus **custom range**. |
| **User (Entra UPN)** | Multi-select dropdown populated from `InitiatingProcessAccountUpn`. `All` by default. |
| **Device** | Multi-select dropdown populated from `DeviceName`. `All` by default. |
| **URL contains** | Free-text substring matched against `RemoteUrl` (`has` operator). |

### Tabs

| # | Tab | Purpose |
|---|---|---|
| 1 | **Top Users / Domains** | Triage landing page. Events-by-category bar chart, Top 25 domains (hits / users / devices), Top 25 users with colored `MaliciousHits` (red) and `AdultHits` (orange) columns. |
| 2 | **Risky User Correlation** | Users who triggered **both** adult/risky web-content events *and* malicious/phishing/techscam SmartScreen events. Includes `FirstAdult`, `FirstMalicious`, `MinutesAdultToMalicious`, sample URLs from each side, and a full filtered event timeline with a `Severity` icon column. |
| 3 | **All Categories (URL+Files)** | Combined `SmartScreenUrlWarning` + `SmartScreenAppWarning` timechart and event grid. Brush-select on the chart to drill into a window. |
| 4 | **Web Content Filter (Adult/Category)** | `ExploitGuardNetworkProtectionBlocked` events parsed for `ResponseCategory` / `ResponseCategoryGroup` / `IsAudit`. Includes a dedicated **Adult / NSFW / Gambling by User & Domain** summary. |
| 5 | **Files (SmartScreenApp)** | `SmartScreenAppWarning` only — file-download SmartScreen blocks. |
| 6 | **TechScam (URL)** | SmartScreen `TechScam` experience. |
| 7 | **Phishing (URL)** | SmartScreen `Phishing` experience. |
| 8 | **Untrusted (URL)** | SmartScreen `Untrusted` experience. |
| 9 | **Malicious (URL)** | SmartScreen `Malicious` experience. |
| 10 | **Custom Block List (URL)** | SmartScreen `CustomBlockList` experience — your custom indicator hits. |
| 11 | **Custom Policy (URL)** | SmartScreen `CustomPolicy` experience — your Web Content Filter policy hits. |

### Data Sources

- `DeviceEvents` (`ActionType` = `SmartScreenUrlWarning`, `SmartScreenAppWarning`, `ExploitGuardNetworkProtectionBlocked`)
- `AdditionalFields.Experience` — SmartScreen verdict label.
- `AdditionalFields.ResponseCategory` and `ResponseCategoryGroup` — Web Content Filtering category.
- `AdditionalFields.IsAudit` — whether the WCF rule was in audit mode.
- `InitiatingProcessAccountUpn` — the Entra UPN of the user whose process triggered the block.

> **Important:** the *content category* (Adult, Pornography, Gambling, etc.) comes **only** from Web Content Filtering on `ExploitGuardNetworkProtectionBlocked` events. SmartScreen's own `Experience` field does **not** include content type — only verdict. If you don't see categorized data in the *Web Content Filter* tab, you likely don't have Web Content Filtering enabled or no WCF policy is assigned to your devices. See [Web content filtering — Microsoft Defender for Endpoint](https://learn.microsoft.com/defender-endpoint/web-content-filtering) to enable it.

---

## Files in This Folder

- `SmartScreen-Web-Threats.json` — workbook JSON payload for manual import via the Sentinel **Advanced Editor**.
- `azuredeploy.json` — one-click ARM deployment template (Azure Commercial and Azure Government).
- `README.md` — this file.

## How To Deploy

Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSmartScreen-Web-Threats-Workbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FSmartScreen-Web-Threats-Workbook%2Fazuredeploy.json)

### Deployment Inputs

When the deployment blade opens, provide:
- `workspaceName`: the Log Analytics workspace name (default: `SOC-Central`).
- `workbookDisplayName` default: `SmartScreen Web Threats`.
- `workbookId`: leave the `newGuid()` default to create a new workbook instance.

### Deployment Note

- The workbook is deployed as `kind: shared` and is scoped to the selected Log Analytics workspace.
- To import the workbook manually instead, open Sentinel **Workbooks** > **+ Add workbook**, click the pencil (Edit) icon, then **Advanced Editor**, and paste the contents of `SmartScreen-Web-Threats.json`.

### CLI Deployment

```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file azuredeploy.json \
  --parameters workspaceName=<your-workspace>
```

---

## KQL Validation

All workbook queries were validated against a live Microsoft Sentinel workspace using `az monitor log-analytics query`. Result summary:

| Query | Result |
|---|---|
| User UPN dropdown | SUCCESS |
| Device dropdown | SUCCESS |
| Overview — Events by Category | SUCCESS |
| Overview — Top 25 Domains | SUCCESS |
| Overview — Top 25 Users | SUCCESS |
| Risky User Correlation grid | SUCCESS |
| Risky User Correlation timeline | SUCCESS |
| All Categories chart | SUCCESS |
| Web Content Filter chart | SUCCESS |
| Web Content Filter grid | SUCCESS |
| Adult/NSFW/Gambling by User & Domain | SUCCESS |
| Files (SmartScreenApp) grid | SUCCESS |
| Malicious (URL) grid | SUCCESS |

---

## License

MIT, same as the parent [Defender_XDR](https://github.com/johnB007/Defender_XDR) repo.
