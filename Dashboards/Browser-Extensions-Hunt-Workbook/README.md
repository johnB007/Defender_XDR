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

![Installed Browser Extensions - Rare or Known-Bad](images/01-installed-extensions.png)

### Tile 2 - Known-Bad & Rare .crx Drops

![Known-Bad & Rare .crx Drops](images/02-crx-id-drops.png)

### Tile 3 - Suspicious No-ID .crx Drops

![Suspicious No-ID .crx Drops](images/03-crx-noid-drops.png)

---

## Known Limitations

- `DeviceFileEvents` only logs **file writes / modifies / deletes**. Extensions that have been installed for a long time and have not auto-updated within the selected time range will **not appear** in any of the three tiles. This is a Defender data-source limitation, not a workbook bug. Use `chrome://extensions` (or Edge equivalent) for a complete on-device inventory.
- Firefox extensions are stored as a single `.xpi` (no deterministic ID); the AMO link is a search. Pivot via `SHA256s` (VirusTotal / MDTI) or inspect `manifest.json` inside the renamed `.xpi`.
- The `ExtensionWhitelist` is opinionated. Edit the `let ExtensionWhitelist = dynamic([...])` block in each KQL tile to match your environment.

---

## Hardening Recommendations

When you find a malicious or unwanted extension, block it via Intune using `ExtensionSettings` policy. See:

- [Manage Microsoft Edge extensions in the enterprise](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions)
- [Use group policies to manage Microsoft Edge extensions](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions-policies)
- [Configure Edge with Intune](https://learn.microsoft.com/deployedge/configure-edge-with-intune)

For Chrome, ingest the [Chrome Enterprise ADMX](https://chromeenterprise.google/browser/download/) into Intune and apply the same `ExtensionInstallBlocklist` / `ExtensionInstallForcelist` / `ExtensionSettings` policies.

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
