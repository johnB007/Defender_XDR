# Browser Extensions Hunt - Unusual & Known-Bad

A Microsoft Sentinel workbook for hunting unusual, rare, and known-bad browser extensions across Chrome, Edge, Brave, and Firefox using **Microsoft Defender for Endpoint** telemetry (`DeviceFileEvents`).

The workbook is built around recent supply-chain and malicious-extension threats including the **Cyberhaven December 2024** compromise, **SquareX Browser Syncjacking 2025**, **RedDirection 2025**, and **Koi Security GreedyBear 2025** patterns.

---

## What It Shows

A single tab group **Unusual & Known-Bad Browser Extensions** with three KQL grids:

| # | Tile | Purpose |
|---|---|---|
| 1 | **Installed Browser Extensions - Rare or Known-Bad** | Scans browser profile directories for installed extensions across Chrome, Edge, Brave, and Firefox. Surfaces extension ID, store-lookup links, droppers, accounts, SHA256s, and a suspicion score. |
| 2 | **Known-Bad & Rare .crx Drops (with extension IDs)** | `.crx` files dropped to disk that include a 32-character extension ID prefix - catches sideload and update activity. |
| 3 | **Suspicious No-ID .crx Drops (dropper + path scored)** | `.crx` files without an ID prefix - flags partial writes, fetcher activity, and unusual dropper paths. |

Each grid produces a **MaxSuspicion** heatmap and three icon columns: `KnownBad`, `OutOfProfile`, `NonBrowserDropper`.

### Suspicion Score

```
toint(KnownBad) * 5
+ toint(not InBrowserProfile)
+ toint(not DropperIsBrowser)
+ toint(InitiatingProcessFolderPath has_any (\Temp\, \Downloads\, \Public\))
```

### Built-In Filters

- **ExtensionWhitelist** - ~33 enterprise / SSO / conferencing / consumer extensions excluded by ID
- **KnownBadIDs** - 7 Cyberhaven IOCs hardcoded as `KnownBad = 1`
- **CrxFilenameWhitelist / BenignFolderPaths** - PowerAutomate Desktop and similar legitimate `.crx` drops scored as `KnownBenign = 0` (visible but suppressed)

---

## Workbook Screenshots

### Tile 1 - Installed Browser Extensions

<img width="2547" height="560" alt="image" src="https://github.com/user-attachments/assets/0a81bb09-9abe-4bb8-881e-9bf0c1017ad9" />


### Tile 2 - Known-Bad & Rare .crx Drops

<img width="2549" height="442" alt="image" src="https://github.com/user-attachments/assets/3a454bec-1cd8-4d5c-b307-175ef9eb6209" />


### Tile 3 - Suspicious No-ID .crx Drops

<img width="2539" height="488" alt="image" src="https://github.com/user-attachments/assets/43085562-3475-42f1-ac20-51a0e94e0107" />


---

## Known Limitations

- `DeviceFileEvents` only logs **file writes / modifies / deletes**. Extensions that have been installed for a long time and have not auto-updated within the selected time range will **not appear** in any of the three tiles. This is a Defender data-source limitation, not a workbook bug. Use `chrome://extensions` (or Edge equivalent) for a complete on-device inventory.
- Firefox extensions are stored as a single `.xpi` (no deterministic ID); the AMO link is a search. Pivot via `SHA256s` (VirusTotal / MDTI) or inspect `manifest.json` inside the renamed `.xpi`.
- The `ExtensionWhitelist` is opinionated. Edit the `let ExtensionWhitelist = dynamic([...])` block in each KQL tile to match your environment.

---

## Hardening Recommendations - Block Extensions via Intune

When you find a malicious or unwanted extension in this workbook, block it at the browser-policy layer. Both Microsoft Edge and Google Chrome share the Chromium policy schema, so the same three policies work for both browsers:

- `ExtensionInstallBlocklist` - deny-list specific IDs (or `*` to block all)
- `ExtensionInstallAllowlist` - allow-list specific IDs (used with a `*` blocklist)
- `ExtensionInstallForcelist` - force-install / pin specific IDs
- `ExtensionSettings` - JSON policy that combines all of the above per-ID with the most flexibility

### Microsoft Edge - Official Docs

- [Manage Microsoft Edge extensions in the enterprise](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions)
- [Use group policies to manage Microsoft Edge extensions](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions-policies) - includes the JSON schema and block-by-update-URL examples
- [Configure Edge with Intune (Settings Catalog)](https://learn.microsoft.com/deployedge/configure-edge-with-intune)
- [Edge security baseline (Intune)](https://learn.microsoft.com/intune/device-security/security-baselines/ref-edge-settings)

In Intune: **Devices > Configuration > Create > New Policy > Windows 10 and later > Settings Catalog**, search for `ExtensionSettings` (or `ExtensionInstallBlocklist` / `ExtensionInstallForcelist`) under **Microsoft Edge**.

### Google Chrome - Via Intune

Microsoft does not host a dedicated Chrome page (Chrome is third-party), but the same policies are deployable two ways:

1. **Ingest Google's ADMX into Intune** ([Import custom ADMX/ADML](https://learn.microsoft.com/intune/configuration/administrative-templates-import-custom)) - download the templates from the [Chrome Enterprise Bundle](https://chromeenterprise.google/browser/download/). The relevant policies are identically named: `ExtensionInstallBlocklist`, `ExtensionInstallForcelist`, `ExtensionSettings`.
2. **OMA-URI custom profile** targeting `./Device/Vendor/MSFT/Policy/Config/Chrome~Policy~googlechrome~Extensions/...` after ADMX ingestion.

### Recipe 1 - Default-Deny All Extensions, Allow Specific IDs

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

- `"*"` is the default rule for all extensions
- Per-ID overrides allow or force-install specific extensions
- For **Edge**, set `update_url` to `https://edge.microsoft.com/extensionwebstorebase/v1/crx`
- For **Chrome**, set `update_url` to `https://clients2.google.com/service/update2/crx`

### Recipe 2 - Block Specific (Bad) Extensions

Deny-list approach if you cannot move to default-deny yet. Useful for blocking the VPN / AI-sidebar / known-bad IDs surfaced in this workbook:

```json
{
  "fjoaledfpmneenckfbpdfhkmimnjocfa": { "installation_mode": "blocked" },
  "bihmplhobchoageeokmgbdihknkjbknd": { "installation_mode": "blocked" },
  "poeojclicodamonabcabmapamjkkmnnk": { "installation_mode": "blocked" }
}
```

`installation_mode: blocked` prevents new installs and **disables** the extension if it is already installed. The files remain on disk - which is exactly why this workbook may not see stable, long-installed extensions: they exist but generate no `DeviceFileEvents` activity.

### Recipe 3 - Block an Entire Web Store

Block the Chrome Web Store update URL while still allow-listing specific Chrome extensions you trust:

```json
{ "update_url:https://clients2.google.com/service/update2/crx": { "installation_mode": "blocked" } }
```

You can still use `ExtensionInstallForcelist` and `ExtensionInstallAllowlist` to allow / force-install specific extensions even when their store is blocked.

### Verification

After deploying the policy, on a managed device:
- Edge: navigate to `edge://policy/` - confirm `ExtensionSettings` is listed under "Policies applied to this profile"
- Chrome: navigate to `chrome://policy/` - confirm the same
- Try installing a blocked extension from the web store - the install button should be disabled with a "Blocked by your administrator" message

---

## Prerequisites

- A Sentinel-enabled Log Analytics workspace
- MDE / Defender for Endpoint streaming `DeviceFileEvents` to that workspace
- Permissions to deploy ARM templates in the target resource group

## Files

- `Browser-Extensions-Hunt.json`: Workbook JSON payload for manual import
- `azuredeploy.json`: One-click ARM deployment template (Commercial + Gov)
- `images/`: Screenshots referenced above

## How To Deploy
Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FBrowser-Extensions-Hunt-Workbook%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FDashboards%2FBrowser-Extensions-Hunt-Workbook%2Fazuredeploy.json)

### Deployment Inputs
When the deployment blade opens, provide:
- `workspaceName` - the Log Analytics workspace name (default: `SOC-Central`)
- `workbookDisplayName` - default: `Browser Extensions Hunt - Unusual & Known-Bad`
- `workbookId` - leave the `newGuid()` default to create a new workbook instance

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

MIT - same as the parent [Defender_XDR](https://github.com/johnB007/Defender_XDR) repo.
