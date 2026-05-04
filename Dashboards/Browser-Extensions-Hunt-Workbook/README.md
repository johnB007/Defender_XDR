# Browser Extensions Hunt: Unusual & Known-Bad

A Microsoft Sentinel workbook for hunting unusual, rare, and known-bad browser extensions across Chrome, Edge, Brave, and Firefox using **Microsoft Defender for Endpoint** telemetry (`DeviceFileEvents`).

---

## What This Workbook Is Built Around

Malicious browser extensions are one of the fastest growing initial-access and data-theft vectors. Unlike traditional malware, extensions run with broad page-content permissions, persist across reboots, survive most EDR detection logic, and are trusted by users because they install from "official" web stores. This workbook is built around four recent threat patterns that publicly demonstrated how attackers abuse the extension ecosystem:

| Threat / Campaign | What Happened | What This Workbook Catches |
|---|---|---|
| **Cyberhaven Supply-Chain Compromise (Dec 2024)** | Attacker phished a maintainer, pushed a trojanized update of the Cyberhaven extension to the Chrome Web Store, then pivoted to ~35 other extensions. Affected millions of installs. | The 7 publicly disclosed Cyberhaven cluster extension IDs are hardcoded in `KnownBadIDs` and surface with `KnownBad = 1` (suspicion +5). |
| **SquareX Browser Syncjacking (2025)** | Malicious extension silently signs the victim into an attacker-controlled Chrome profile, exfiltrating browsing data, cookies, and saved credentials via Chrome Sync. | Tile 1 surfaces newly installed or out-of-profile extensions; pivot the `Devices` and `Accounts` columns to investigate. |
| **RedDirection (2025)** | 18 malicious extensions across Chrome and Edge stores hijacked search results and redirected traffic to attacker-monetized destinations. | Tile 1 (rare extensions) plus Tile 2 (`.crx` drops with IDs) catch installs that fall outside the curated `ExtensionWhitelist`. |
| **Koi Security GreedyBear (2025)** | Bundled malicious extensions distributed through bundleware or fake installers; arrived as `.crx` files dropped by non-browser processes. | Tile 2 and Tile 3 score `.crx` drops where the dropper is not a browser process and the path is outside the normal browser profile. |

The scoring model assumes attackers will violate at least one of these invariants: extension is on a known-bad list, the file lands outside a real browser profile, the dropper is not a browser process, or the file lands in a user-writable temp, download, or public path. See the **Suspicion Score** below for the formula.

---

## How To Use This Workbook

### Sysadmins and IT Operations

- **Daily or weekly review** of Tile 1 to identify extensions installed outside the approved `ExtensionWhitelist`. Update the whitelist when you onboard new business-approved extensions so the noise floor stays clean.
- **Onboarding new endpoints**: filter Tile 1 by `Devices` to confirm a freshly imaged device only has corporate-approved extensions installed.
- **Inventory pivot**: use the Chrome / Edge Web Store / AMO `StoreLookup` and `AltStoreLookup` columns to verify a publisher and reach out to a user if an extension looks legitimate but unexpected.
- **Hardening enforcement**: feed any blocked IDs into the Intune `ExtensionSettings` recipes at the bottom of this README, then re-run the workbook in 7 days to confirm the install count drops to zero.
- **CSV export** is enabled on every grid (advanced setting `Show Export to CSV button when not editing`). Export inventories for vendor conversations, audit reviews, or asset-management ticket attachments.

### SOC Analysts and Threat Hunters

- **Triage workflow**: sort by `KnownBad` desc, then `MaxSuspicion` desc (heatmap red). Anything red on the left is your hottest lead.
- **Cyberhaven check**: any row with `KnownBad = 1` is a publicly known IOC. Open an incident immediately and isolate the device.
- **Sideload and drop hunting**: Tile 2 surfaces `.crx` drops containing an extension ID. Pivot the `Droppers`, `DropperPaths`, and `InitiatingProcessFolderPath` columns. Browser-by-browser drops are normal; `powershell.exe`, `curl.exe`, `7z.exe`, or paths under `\Users\Public\` or `\Temp\` are not.
- **No-ID `.crx` hunting**: Tile 3 catches partial writes and fetcher activity. The `KnownBenign` column lets you keep visibility on legitimate Power Automate Desktop drops without losing sight of new noise.
- **VirusTotal and MDTI pivot**: every grid exposes `SHA256s` as an array. Paste any hash into VirusTotal or Microsoft Defender Threat Intelligence to enrich your investigation.
- **Account compromise lead**: the `Accounts` column shows which user(s) had the extension under their profile. Combine with `IdentityLogonEvents` and `EmailEvents` to scope blast radius.
- **Build a watch list**: when a new public IOC drops (e.g. a fresh Koi Security or SquareX disclosure), add the extension IDs to the `KnownBadIDs` `dynamic([...])` block in each tile's KQL and the workbook will instantly retro-hunt that ID across your entire `DeviceFileEvents` retention window.

### Compliance and Audit

- **Browser extension inventory** is a frequent ask in CIS, NIST 800-53, and customer security questionnaires. Use the CSV export from Tile 1 as the system-of-record artifact.
- The **OutOfProfile** and **NonBrowserDropper** flags map cleanly to "unauthorized software installation" findings.

---

## What It Shows

A single tab group **Unusual & Known-Bad Browser Extensions** with three KQL grids:

| # | Tile | Purpose |
|---|---|---|
| 1 | **Installed Browser Extensions: Rare or Known-Bad** | Authoritative inventory tile. Walks every Chrome, Edge, Brave, and Firefox profile directory across `DeviceFileEvents` to enumerate every installed extension by ID. Filters out the curated `ExtensionWhitelist` (~33 approved IDs) and tags any match against `KnownBadIDs` (Cyberhaven IOCs). For each surviving extension it surfaces: extension ID, browser, direct-click `StoreLookup` and `AltStoreLookup` URLs (Chrome Web Store, Edge Add-ons, Firefox AMO), `FirstSeen` and `LastSeen` timestamps, `DeviceCount`, every device that has it installed, full `FolderPaths`, the dropping process (`Droppers` plus `DropperPaths`), `Accounts` that own the profile, all observed `SHA256s` for VT/MDTI pivot, and the four flag columns: `KnownBad`, `OutOfProfile`, `NonBrowserDropper`, `MaxSuspicion`. **Use this tile** to answer "what's installed in my fleet that I don't recognize?" |
| 2 | **Known-Bad and Rare .crx Drops (with extension IDs)** | Drop and sideload tile. Watches `DeviceFileEvents` for `.crx` files whose filename begins with a 32-character lowercase extension ID prefix, the canonical Chrome and Edge install package. Catches every install, update, and policy push to the Chromium-based browsers, including those delivered by `msedge_url_fetcher_*` and `chromecrx_chrome_url_fetcher_*` helper processes (now classified as "in-profile" so they don't false-positive). Flags any drop where the dropper is not a browser process or the destination is outside a real browser `Extensions\` directory. **Use this tile** to catch supply-chain pushes (Cyberhaven-style auto-updates), malicious sideloads, and policy-deployed extensions. |
| 3 | **Suspicious No-ID .crx Drops (dropper plus path scored)** | Anomaly and bundleware tile. Watches `DeviceFileEvents` for `.crx` files **without** a 32-character ID prefix. These are non-canonical and almost always indicate one of: (a) a partial write captured mid-stream by Defender, (b) a renamed `.crx` from a malicious installer, (c) bundleware dropping a payload to disk before browser-side install, (d) legitimate enterprise tooling (e.g. Power Automate Desktop's `pad_extension_for_chrome.crx`). The `KnownBenign` flag lets PAD-style legit drops stay visible but score 0, while the `BenignFolderPaths` list suppresses `\WindowsApps\Microsoft.PowerAutomateDesktop` drops to score 0 as well. Filename-whitelisted (`pad_extension_for_chrome`, `msedge*`) drops are kept but neutralized. **Use this tile** to catch GreedyBear-style bundleware and any unusual-named `.crx` that doesn't fit the canonical install pattern. |

Each grid produces a **MaxSuspicion** heatmap (red = hot) and three icon columns: `KnownBad` (cluster IOC), `OutOfProfile` (file landed outside a real browser profile), `NonBrowserDropper` (the writing process is not a known browser binary). Sort by `KnownBad` desc, then `MaxSuspicion` desc, then `DeviceCount` desc to triage.

### Suspicion Score

```
toint(KnownBad) * 5
+ toint(not InBrowserProfile)
+ toint(not DropperIsBrowser)
+ toint(InitiatingProcessFolderPath has_any (\Temp\, \Downloads\, \Public\))
```

### Built-In Filters

- **ExtensionWhitelist**: ~33 enterprise, SSO, conferencing, and consumer extensions excluded by ID.
- **KnownBadIDs**: 7 Cyberhaven IOCs hardcoded as `KnownBad = 1`.
- **CrxFilenameWhitelist and BenignFolderPaths**: PowerAutomate Desktop and similar legitimate `.crx` drops scored as `KnownBenign = 0` (visible but suppressed).

---

## Workbook Screenshots

### Tile 1: Installed Browser Extensions

<img width="2547" height="560" alt="image" src="https://github.com/user-attachments/assets/0a81bb09-9abe-4bb8-881e-9bf0c1017ad9" />


### Tile 2: Known-Bad and Rare .crx Drops

<img width="2549" height="442" alt="image" src="https://github.com/user-attachments/assets/3a454bec-1cd8-4d5c-b307-175ef9eb6209" />


### Tile 3: Suspicious No-ID .crx Drops

<img width="2539" height="488" alt="image" src="https://github.com/user-attachments/assets/43085562-3475-42f1-ac20-51a0e94e0107" />


---

## Known Limitations

- `DeviceFileEvents` only logs **file writes, modifies, and deletes**. Extensions that have been installed for a long time and have not auto-updated within the selected time range will **not appear** in any of the three tiles. This is a Defender data-source limitation, not a workbook bug. Use `chrome://extensions` (or Edge equivalent) for a complete on-device inventory.
- Firefox extensions are stored as a single `.xpi` (no deterministic ID); the AMO link is a search. Pivot via `SHA256s` (VirusTotal or MDTI) or inspect `manifest.json` inside the renamed `.xpi`.
- The `ExtensionWhitelist` is opinionated. Edit the `let ExtensionWhitelist = dynamic([...])` block in each KQL tile to match your environment.

---

## Hardening Recommendations: Block Extensions via Intune

When you find a malicious or unwanted extension in this workbook, block it at the browser-policy layer. Both Microsoft Edge and Google Chrome share the Chromium policy schema, so the same three policies work for both browsers:

- `ExtensionInstallBlocklist`: deny-list specific IDs (or `*` to block all).
- `ExtensionInstallAllowlist`: allow-list specific IDs (used with a `*` blocklist).
- `ExtensionInstallForcelist`: force-install or pin specific IDs.
- `ExtensionSettings`: JSON policy that combines all of the above per-ID with the most flexibility.

### Microsoft Edge (Official Docs)

- [Manage Microsoft Edge extensions in the enterprise](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions)
- [Use group policies to manage Microsoft Edge extensions](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions-policies) — includes the JSON schema and block-by-update-URL examples.
- [Configure Edge with Intune (Settings Catalog)](https://learn.microsoft.com/deployedge/configure-edge-with-intune)
- [Edge security baseline (Intune)](https://learn.microsoft.com/intune/device-security/security-baselines/ref-edge-settings)

In Intune: **Devices > Configuration > Create > New Policy > Windows 10 and later > Settings Catalog**, search for `ExtensionSettings` (or `ExtensionInstallBlocklist` / `ExtensionInstallForcelist`) under **Microsoft Edge**.

### Google Chrome (Via Intune)

Microsoft does not host a dedicated Chrome page (Chrome is third-party), but the same policies are deployable two ways:

1. **Ingest Google's ADMX into Intune** ([Import custom ADMX/ADML](https://learn.microsoft.com/intune/configuration/administrative-templates-import-custom)). Download the templates from the [Chrome Enterprise Bundle](https://chromeenterprise.google/browser/download/). The relevant policies are identically named: `ExtensionInstallBlocklist`, `ExtensionInstallForcelist`, `ExtensionSettings`.
2. **OMA-URI custom profile** targeting `./Device/Vendor/MSFT/Policy/Config/Chrome~Policy~googlechrome~Extensions/...` after ADMX ingestion.

### Recipe 1: Default-Deny All Extensions, Allow Specific IDs

Most secure posture. Set `ExtensionSettings` (one policy value per browser):

```json
{
  "*": { "installation_mode": "blocked" },
  "ghbmnnjooekpmoecnnnilnnbdlolhkhi": {
    "installation_mode": "force_installed",
    "update_url": "https://clients2.google.com/service/update2/crx"
  }
}
```

- `"*"` is the default rule for all extensions.
- Per-ID overrides allow or force-install specific extensions.
- For **Edge**, set `update_url` to `https://edge.microsoft.com/extensionwebstorebase/v1/crx`.
- For **Chrome**, set `update_url` to `https://clients2.google.com/service/update2/crx`.

### Recipe 2: Block Specific (Bad) Extensions

Deny-list approach if you cannot move to default-deny yet. Useful for blocking the VPN, AI sidebar, or known-bad IDs surfaced in this workbook:

```json
{
  "fjoaledfpmneenckfbpdfhkmimnjocfa": { "installation_mode": "blocked" },
  "bihmplhobchoageeokmgbdihknkjbknd": { "installation_mode": "blocked" },
  "poeojclicodamonabcabmapamjkkmnnk": { "installation_mode": "blocked" }
}
```

`installation_mode: blocked` prevents new installs and **disables** the extension if it is already installed. The files remain on disk, which is exactly why this workbook may not see stable, long-installed extensions: they exist but generate no `DeviceFileEvents` activity.

### Recipe 3: Block an Entire Web Store

Block the Chrome Web Store update URL while still allow-listing specific Chrome extensions you trust:

```json
{ "update_url:https://clients2.google.com/service/update2/crx": { "installation_mode": "blocked" } }
```

You can still use `ExtensionInstallForcelist` and `ExtensionInstallAllowlist` to allow or force-install specific extensions even when their store is blocked.

### Verification

After deploying the policy, on a managed device:
- Edge: navigate to `edge://policy/` and confirm `ExtensionSettings` is listed under "Policies applied to this profile".
- Chrome: navigate to `chrome://policy/` and confirm the same.
- Try installing a blocked extension from the web store. The install button should be disabled with a "Blocked by your administrator" message.

---

## Prerequisites

- A Sentinel-enabled Log Analytics workspace
- MDE / Defender for Endpoint streaming `DeviceFileEvents` to that workspace
- Permissions to deploy ARM templates in the target resource group

## Files

- `Browser-Extensions-Hunt.json`: workbook JSON payload for manual import.
- `azuredeploy.json`: one-click ARM deployment template (Commercial plus Gov).
- `images/`: screenshots referenced above.

## How To Deploy
Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FBrowser-Extensions-Hunt-Workbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FBrowser-Extensions-Hunt-Workbook%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- `workspaceName`: the Log Analytics workspace name (default: `SOC-Central`).
- `workbookDisplayName` default: `Browser Extensions Hunt: Unusual & Known-Bad`.
- `workbookId`: leave the `newGuid()` default to create a new workbook instance.

### Deployment Note
- The workbook is deployed as `kind: shared` and is scoped to the selected Log Analytics workspace.
- To import the workbook manually instead, open Sentinel **Workbooks** > **+ Add workbook**, click the pencil (Edit) icon, then **Advanced Editor**, and paste the contents of `Browser-Extensions-Hunt.json`.

### CLI Deployment

```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file azuredeploy.json \
  --parameters workspaceName=<your-workspace>
```

---

## License

MIT, same as the parent [Defender_XDR](https://github.com/johnB007/Defender_XDR) repo.
