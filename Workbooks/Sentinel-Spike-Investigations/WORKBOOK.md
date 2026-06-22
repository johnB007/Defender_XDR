# Sentinel Spike Investigator workbook

The Sentinel Workbook in this package is the automated path for the
playbook alongside it. Instead of opening the seven `.kql`
files one at a time and pasting results between tabs, the workbook
runs every step in place against the connected Log Analytics
workspace with color coded deltas, vendor and product attribution,
and click to drill on devices.

This README documents the import, the parameters, every step in the
workbook, and how to extend it.

## Prerequisites

1. A Sentinel enabled Log Analytics workspace.
2. The **Microsoft Defender XDR** data connector turned on so the
   `Device*` tables land in the workspace. Without the connector the
   queries return zero rows. The raw `.kql` files still work in
   Defender XDR Advanced Hunting in that case.
3. Workbook contributor permissions on the workspace, or the
   workspace owner running the import on your behalf.

## One time import

1. Sentinel : Workbooks : **+ Add workbook**.
2. **Edit** (pencil icon).
3. **Advanced Editor** (the `</>` icon at the top of the edit toolbar).
4. Gallery Template kind: **JSON**.
5. Paste the entire contents of
   [Sentinel-Spike-Investigations.workbook](Sentinel-Spike-Investigations.workbook)
   into the editor. Replace whatever placeholder is already there.
6. **Apply**.
7. **Done Editing**.
8. **Save**. Pick a workspace and a name (suggested: `Spike Investigator`).

Once saved, the workbook appears under **My workbooks** and can be
opened any time a spike alert fires.

## Updating the workbook later

When this repo ships a new version, repeat the import:

1. Open the saved workbook in Sentinel.
2. Edit : Advanced Editor.
3. Replace the JSON with the new contents of
   `Sentinel-Spike-Investigations.workbook`.
4. Apply : Done Editing : Save.

The workbook does not auto update. If you want the latest version,
you re paste it.

## The parameters at the top

Every query in the workbook is driven from a parameter row at the
top. Setting these is the only step you take per investigation.

| Parameter | Type | Default | What it does |
|---|---|---|---|
| `Table` | dropdown | `DeviceFileEvents` | The `Device*` table to investigate. Drives Steps 1 through 5. |
| `SpikeRange` | time range picker | last 3 days | Start and end of the spike window. Drives every query. |
| `BaselineRange` | time range picker | last 14 days ending at the spike start | Comparison window for Steps 0, 2, and 3. |
| `SelectPct` | text | `5` | Floor for which ActionTypes Step 2's chart shows. Lower means more bars, more noise. |
| `Threshold` | text | `10000` | The `Spike > N` cutoff in Step 3. Raise on very high volume tables. |
| `Device` | text | empty | The device name Step 5 drills into. Set by clicking a row in Step 4. |

The two time pickers are independent. Set the `SpikeRange` to the
days that look high. Set the `BaselineRange` to a comparable period
of normal volume. Two weeks ending at the spike start is the
default and a good choice.

## The sections, top to bottom

The workbook renders the same flow as the playbook with two
additions at the top: an intro and an anomaly scan.

### Intro

Plain text explaining what the workbook does and how the parameters
drive it. No queries.

### Anomalous tables (last 30 days, score >= 3)

`q-anomaly`. A 30 day anomaly scan across every billable table using
`series_decompose_anomalies`. Surfaces tables whose daily volume
spiked abruptly in a single day and scored above the standard
threshold.

Columns: `DataType`, `AnomalyDay`, `Actual` (GB on that day),
`Expected` (expected GB from the linefit baseline), `Score`,
`PercentIncrease`.

- The scan catches abrupt one day spikes. Sustained multi day rises
  are absorbed into the linefit baseline and do not surface here.
  Use Steps 0 through 3 for sustained rises.
- `PercentIncrease` uses the standard formula `(Actual - Expected) / Expected`
  so a 100 to 1000 jump reads as 900 percent, not 90 percent.
- A `MinDailyVolume = 100` floor filters out near zero tables that
  read as 100 percent anomalies on a 0 row to 1 row jump.
- Zero rows is the healthy state.

### Step 0 : confirm the spike

Two visualisations side by side.

- `q-step0`. Barchart titled "Events per day: baseline window vs
  spike window" for the selected `Table`. Both bars are per day
  normalised so a 3 day spike compares directly against a 14 day
  baseline.
- `q-step0-trend`. Linechart spanning both windows so the analyst
  can see the full daily trend rather than just the two summary
  bars. Useful to spot a multi day ramp vs a one day spike.

### Step 1 : ActionType breakdown during the spike

`q-step1`. Table showing the top 20 ActionType values during the
spike window with vendor attribution. Columns: `ActionType`,
`Events`, `Devices`, `EventsPerDevice`, `TopInitiator`,
`TopCompany`.

The attribution is a join against the binary metadata so the table
shows which publisher's binary produced each ActionType, not just
the action name. A single ActionType driven by `MsMpEng.exe` from
Microsoft Corporation tells a different story than the same
ActionType driven by an unknown binary.

### Step 2 : ActionType spike vs baseline

Two views.

- `q-step2`. Numeric table per ActionType: `BasePerDay`, `SpikePerDay`,
  `Delta`, `Ratio`. Same shape as the per day normalisation in Step 0
  but split by ActionType.
- `q-step2-chart`. Top 15 ActionTypes with the same numbers in a
  table that uses the following coloring:
  - `BasePerDay`: blue heatmap. Higher is darker blue.
  - `SpikePerDay`: red heatmap. Higher is darker red.
  - `Delta`: diverging thresholds. Positive deltas are red (above
    baseline). Negative deltas are green (below baseline). Zero is
    grey.

### Step 3 : process pairs that grew the most

`q-step3`. The most important table in the workbook. Same query as
[kql/03_spike_vs_baseline.kql](kql/03_spike_vs_baseline.kql) but with
two upgrades:

- **Per day normalisation** of both Spike and Baseline.
- **Vendor and product attribution** joined on
  `InitiatingProcessFileName` so the table shows publisher and
  product name next to the binary even when the file name alone is
  generic.

Columns: `ParentName`, `InitName`, `Vendors`, `Products`,
`BasePerDay`, `SpikePerDay`, `Delta`, `Ratio`, `AboveThreshold`.

The `AboveThreshold` column uses true/false text with threshold
coloring: green `true` when the row is above the `Threshold`
parameter, red `false` when it is below. Sort by `Delta` descending
and read the top five rows.

`Delta` uses the same diverging thresholds as Step 2's chart so the
sign is obvious at a glance.

### Step 4 : devices contributing the most rows

`q-step4`. Top 50 devices in the spike with `Events`,
`DistinctInitiators`, `TopInitiator`, `FleetShare` percent. **Click
any row** and the workbook pins that device name into the `Device`
parameter, which makes Step 5 appear below.

### Step 5 : process tree for `{Device}`

`q-step5`. Top process pairs on the device the analyst clicked in
Step 4, in the spike window, with the same vendor and product
attribution join as Step 3.

Columns: `ParentName`, `InitName`, `Vendors`, `Products`, `Events`.

The query is hidden until a `Device` is selected. To clear it, set
the `Device` parameter to empty at the top of the workbook.

## What the workbook does not do

- It does not write back to Sentinel. The output is a view and a
  closeout, not an automated action.
- It does not run anything on a schedule. It runs when an analyst
  opens it and sets the time pickers.
- The dataset is whatever is in Log Analytics. If MDE streaming is
  filtered or delayed at the connector, the workbook reflects that.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Every query returns "no data" | Defender XDR data connector is off or the chosen `Table` is empty | Enable the Defender XDR data connector. Pick another `Table` from the dropdown. |
| Step 3 returns hundreds of rows | `Threshold` parameter is too low for the table volume | Raise `Threshold` to `100000` or `1000000`. |
| Step 5 is blank | `Device` parameter is empty | Click any row in Step 4 to pin a device. |
| A column shows true/false as plain text | The workbook was edited and the threshold representation was changed | The threshold `representation` must be one of `Success` / `Failed` / `Critical` / `Warning` / `Pending` / `Info` / `Unknown` / `Disabled`. Heatmap palette names like `green`, `redBright` only work for formatter type 4, not for threshold formatter type 18. |
| `Delta` column is all red regardless of sign | `Delta` is using a monochrome palette instead of diverging thresholds | Switch the column formatter to type 18 (thresholds) with `> 0 -> Failed`, `< 0 -> Success`, default `Unknown`. |
| Anomaly section returns zero rows | No abrupt one day spikes in the last 30 days | Healthy state. Run Steps 0 through 3 for sustained, multi day rises. |

## File layout

| File | What it is |
|---|---|
| [Sentinel-Spike-Investigations.workbook](Sentinel-Spike-Investigations.workbook) | The workbook JSON. Paste this into the Advanced Editor. |
| [WORKBOOK.md](WORKBOOK.md) | This file. Import instructions and per item documentation. |
| [WORKBOOK.html](WORKBOOK.html) | Rendered HTML sibling. Same content as the Markdown, no viewer required. |
