# MDE Custom Data Collection Validation Workbook

A Microsoft Sentinel workbook for teaching and validating MDE Custom Data Collection rules across all six `DeviceCustom*Events` tables. Every tab compares the default sensor table against the custom rule feed on the same devices and time window, and highlights values only the custom feed sees, so a class or a validation pass has a concrete, provable answer instead of a guess.

---

## What This Package Contains

| Path | Description |
|---|---|
| `deployment/MDE-Custom-Data-Collection-Validation.workbook` | Importable Microsoft Sentinel workbook definition |
| `deployment/azuredeploy.json` | One click ARM deployment template (Commercial plus Gov) |
| `support/Invoke-Regsvr32SquiblydooGenerator.ps1` | Generates regsvr32 Squiblydoo activity so the tables have real data to compare |
| `support/Invoke-MDECustomTelemetryProbe.ps1` | Fires one benign, marker tagged event into all six custom tables to confirm a rule is streaming |

---

## Tab Guide

| Tab | Default table | Custom table | What the tab proves |
|---|---|---|---|
| Overview | all six default tables | all six custom tables | Event volume, ingestion GB per day, and per device custom table coverage, side by side |
| Process | `DeviceProcessEvents` | `DeviceCustomProcessEvents` | Default already covers process creation, custom wins on a scoped, complete feed tagged with `RuleName`, not new fields |
| Network | `DeviceNetworkEvents` | `DeviceCustomNetworkEvents` | Default is heavily curated, custom streams far more connection events, the largest volume uplift outside Image load |
| File | `DeviceFileEvents` | `DeviceCustomFileEvents` | Property options differ per action type (Created, Modified, Deleted, Renamed), and Linux (preview) exposes its own action set and fields |
| Registry (preview) | `DeviceRegistryEvents` | `DeviceCustomRegistryEvents` | Stays empty until a Registry rule is enabled, the exact gap the class needs to see and close |
| Image load | `DeviceImageLoadEvents` | `DeviceCustomImageLoadEvents` | Default is nearly empty by design, custom captures the full module load chain |
| Script | script related `DeviceEvents` | `DeviceCustomScriptEvents` | No default dedicated script table, custom adds `ScriptContent` and `ScriptContentSHA256` as first class fields instead of buried JSON |

Every tab also has a **Values only seen in custom** grid, every distinct value from the custom feed checked against the default feed on the same devices and window, with an `OnlyInCustom` column colored green. Pick any green row to search, no need to already know the rule's scope.

---

## Turning on the tables for testing

Each table needs its own custom data collection rule (Defender portal, Settings, Endpoints, Custom data collection rules). One action type per rule, and a single wide open condition so nothing gets filtered out:

| Table | Action type | Condition |
|---|---|---|
| Process | ProcessCreated | ProcessCommandLine, Not equals, blank |
| Image load | ImageLoaded | FileName, Not equals, blank |
| File | FileCreated | FileName, Not equals, blank |
| Network event | ConnectionSuccess | RemotePort, Not equals, 0 |
| Registry (preview) | RegistryValueSet | RegistryKey, Not equals, blank |
| Script | AmsiScriptContent | InitiatingProcessFileName, Not equals, blank |

Requires MDE Plan 2 and a Sentinel workspace already connected to the tenant. Telemetry starts flowing 20 minutes to 1 hour after a rule deploys, and every rule caps at 75,000 events per device per 24 hour rolling window.

---

## Prerequisites

- MDE Plan 2.
- A Sentinel enabled Log Analytics workspace, one per tenant, connected before rules are created.
- Permission to create custom data collection rules and to deploy or import the workbook.

## Known Limitations

- Each rule allows exactly one action type. Network exposes 17 action types in the wizard, one rule only streams one of them, build a second rule for `ConnectionAttempt` or `ConnectionFailed` if a C2 hunt needs them too.
- Script content from `scrobj.dll` running outside AMSI (the regsvr32 Squiblydoo scriptlet variant) is a blind spot on both the default and custom feed, see the deck's regsvr32 walkthrough.
- File on Linux (preview) drops `FileModified` and uses Linux paths, it is a separate rule and a separate workbook tab state, not a toggle on the Windows rule.
- Registry has no dedicated default advanced hunting experience for several action types (Queried, Enumerated), so the custom feed is the only view for those.

---

## How To Deploy

Use one of the deployment buttons below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FWorkbooks%2FMDE-Custom-Data-Collection-Validation%2Fdeployment%2Fazuredeploy.json)

[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FWorkbooks%2FMDE-Custom-Data-Collection-Validation%2Fdeployment%2Fazuredeploy.json)

To import manually instead, open Sentinel **Workbooks** > **+ Add workbook**, select the pencil (Edit) icon, then **Advanced Editor**, and paste the contents of `deployment/MDE-Custom-Data-Collection-Validation.workbook`.

## How To Use This Workbook

1. Open the workbook in Sentinel, confirm the **Workspace** parameter points at the tenant's connected Log Analytics workspace.
2. Set **Time Range** and, optionally, a **Device** filter.
3. Start on **Overview** to confirm which tables have custom collection turned on and how much volume each is adding.
4. Walk each table tab, compare the default and custom grids side by side, then use the **Values only seen in custom** grid to pick a real search term and confirm the split yourself.

## License And Attribution

MIT, same as the parent [Defender_XDR](https://github.com/johnB007/Defender_XDR) repo.
