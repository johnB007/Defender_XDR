# Template Workbook

A Microsoft Sentinel starter shell workbook for anyone who needs to begin a custom investigation without writing a workbook from scratch. It has two tabs, six ready-to-replace KQL query tiles, six matching time series charts with time brushing, and built-in instructions on every tab so the recipient knows exactly what to change and how.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FWorkbooks%2FTemplate-Workbook%2Fazuredeploy.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FjohnB007%2FDefender_XDR%2Fmain%2FWorkbooks%2FTemplate-Workbook%2Fazuredeploy.json)

---

## Who this is for

This workbook is a handoff artifact. Give it to an analyst, a sysadmin, or a customer who has never built a Sentinel workbook before. Everything they need to know is written directly inside the workbook tiles. They replace the example queries with their own KQL and they are done.

---

## What it does

Two tabs share three global parameters at the top.

### Global parameters

| Pill | Controls | Notes |
|---|---|---|
| **Time Range** | The six chart tiles on the Visuals tab | Change this to set how far back the charts look. Default is Last 7 days. |
| **Select User** | Every query on both tabs via the `{SelectedUser}` token | Populated from `SigninLogs`. Leave blank to see all users. |
| **Results Window** | The six result grids on the Visuals tab | Updated automatically when you drag-select a spike on a chart. Reset by clicking this pill and picking a new window. |

### Tab 1 - KQL Queries

Six KQL query tiles arranged two across per row (three rows of two = six total). Each runs a query and shows results as a sortable table.

| Tile | Example query included | Table |
|---|---|---|
| KQL 1 | Sign-in summary by application | `SigninLogs` |
| KQL 2 | Failed sign-in errors by result code | `SigninLogs` |
| KQL 3 | Sign-in locations (country, city) | `SigninLogs` |
| KQL 4 | Audit log operations and outcomes | `AuditLogs` |
| KQL 5 | Audit log target resources | `AuditLogs` |
| KQL 6 | Sign-in device and client details | `SigninLogs` |

Every example query filters by `{SelectedUser}` with a short-circuit condition so an empty user selection returns all rows.

### Tab 2 - Visuals

The same six queries rendered as time series charts, each with a matching result grid directly below it.

**Time brushing workflow:**
1. Look for a spike on any chart.
2. Click and drag across that spike. A blue selection appears on the chart.
3. The **Results Window** pill at the top updates to that narrow time window. The charts stay at the full **Time Range** and do not move.
4. The six result grids below immediately re-run and show only rows from that narrow window.
5. To reset the grids: click the **Results Window** pill and pick your original window (for example Last 7 days).

---

## How to customize

### Replace a query

1. Click the **pencil icon** in the top-right corner of any tile while the workbook is in edit mode.
2. Delete the example KQL and paste your own.
3. Keep `{SelectedUser}` anywhere you want the user filter applied. The workbook substitutes the selected user at run time. If the user pill is blank the condition is skipped and all rows are returned.
4. Change the **Title** field at the top of the edit panel to rename the tile.
5. Click **Done Editing**, then **Save** in the top toolbar.

### Change a chart type

1. Click the pencil on a chart tile.
2. Open the **Visualization** dropdown and choose area chart, bar chart, pie chart, or scatter.
3. Use **Chart Settings** to rename series or adjust axis labels.
4. Your query must return a datetime column (for example `bin(TimeGenerated, 1h)`) for any chart type to render correctly.

### Change layout width

Open a tile in edit mode and adjust the **Custom width** percentage:

| Value | Layout |
|---|---|
| 50 | Two tiles side by side (current default) |
| 33 | Three tiles per row |
| 100 | Full width, one tile per row |

### Add more tiles

In edit mode, scroll to the bottom of a tab group and click **Add query**.

### Save the workbook

Click **Save** in the top toolbar. Give it a name and pick a Log Analytics workspace or resource group. Once saved, share the link via the **Share** button.

---

## Data sources

| Table | Used in |
|---|---|
| `SigninLogs` | KQL 1, 2, 3, 6 and their matching visual tiles |
| `AuditLogs` | KQL 4, 5 and their matching visual tiles |

Both tables are standard Microsoft Entra log sources connected to Sentinel via the **Azure Active Directory** data connector. If either table is empty in your workspace, connect the data connector under **Sentinel > Content hub > Azure Active Directory**.

---

## Importing this workbook into Sentinel

1. Open Microsoft Sentinel.
2. Navigate to **Workbooks** in the left menu.
3. Click **Add workbook**.
4. Click the **Advanced Editor** button (the `</>` icon).
5. Delete all existing content in the editor.
6. Paste the contents of `Template-Workbook.workbook` from this folder.
7. Click **Apply**, then **Save**.