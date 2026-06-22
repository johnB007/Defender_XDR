# Sentinel Spike Investigations

A complete, repeatable answer to one question:

> Table X in Sentinel just spiked. What is driving it, and what do I
> tell leadership?

The package contains a step by step KQL playbook and a Sentinel Workbook
that automates the whole flow so most investigations finish in minutes
with a ready to paste closeout.

## Who this is for

- SOC analysts on the front line of ingestion alerts.
- Detection engineers tuning data collection rules.
- Sentinel and Defender XDR admins who need to defend ingestion cost
  to leadership.
- Anyone who has ever had to answer the question "why did our log
  bill go up this week" in a hurry.

## What is in this folder

| File or folder | What it is |
|---|---|
| [README.md](README.md) | This file. Start here. |
| [PLAYBOOK.md](PLAYBOOK.md) | The manual, query by query procedure. Edit one date block, run, read, repeat. |
| [Sentinel-Spike-Investigations.workbook](Sentinel-Spike-Investigations.workbook) | An optional Sentinel Workbook that runs every step of the playbook in place, with color coded deltas, attribution lookup, and drilldown on click. Import once via Sentinel : Workbooks : Add workbook : Advanced Editor. |
| [WORKBOOK.md](WORKBOOK.md) | One time import instructions and an item by item tour of the workbook. |
| [kql/](kql/) | The seven numbered KQL files. Work them in order. |
| [kql/00_what_table_spiked.kql](kql/00_what_table_spiked.kql) | Ranks every billable `DataType` by daily GB delta. Names the table that grew. |
| [kql/01_when_spiked_timechart.kql](kql/01_when_spiked_timechart.kql) | Hourly timechart for the suspect table across the spike window plus 7 days of baseline. Pins the start hour. |
| [kql/02_top_actiontypes.kql](kql/02_top_actiontypes.kql) | For tables with an `ActionType` column, ranks ActionType during the spike. Usually one or two ActionTypes account for most of the volume. |
| [kql/03_spike_vs_baseline.kql](kql/03_spike_vs_baseline.kql) | The key query. Joins spike vs prior 7 days grouped by parent process, init process, and company. Top row almost always names the binary. |
| [kql/04_top_destinations.kql](kql/04_top_destinations.kql) | Once a binary is named, shows where it is writing files, connecting on the network, touching the registry, or loading DLLs. |
| [kql/05_device_concentration.kql](kql/05_device_concentration.kql) | Top 25 devices with FleetShare percent. Decides fleet wide rollout vs a handful of broken hosts. |
| [kql/06_drill_processtree.kql](kql/06_drill_processtree.kql) | Full parent chain for the suspect process on one device in a 3 hour window. The proof you paste into the brief. |

Every Markdown file has a sibling `.html` rendered with the same
template so the package can be browsed without a Markdown viewer.

## The three modes of use

You can drive this package in three different ways depending on how
much tooling you have. Pick the one that fits your environment.

### Mode 1 : KQL only

Open Advanced Hunting (Defender XDR) and Sentinel Logs in side by
side browser tabs. Work the seven `.kql` files in order. Edit one
date block per file. No imports, no setup, no extra permissions.
This is the canonical mode and works in any tenant.

Best for: a one off spike, a tenant where you do not own the
workbook gallery, training a new analyst from first principles.

### Mode 2 : Workbook

Import [Sentinel-Spike-Investigations.workbook](Sentinel-Spike-Investigations.workbook)
into Sentinel : Workbooks once. After that every spike becomes a
fill in the parameters exercise. The workbook runs every query, color
codes the deltas (green = below baseline, red = above), shows vendor
and product attribution next to each binary, and lets you click a
device row to pin Step 5.

Best for: a SOC that responds to ingestion alerts more than once a
month. The setup pays for itself the second time you use it.

### Mode 3 : Both

Use the workbook for the first pass. When something does not fit a
known pattern, drop into the raw KQL files to extend, customise,
or save a tenant specific variant. The workbook and the files share
the same query shapes so what you learn in one transfers cleanly to
the other.

## Fast path

If a spike alert just fired and you have an hour, do this:

1. Open [PLAYBOOK.md](PLAYBOOK.md).
2. Run Step 0 in Sentinel Logs to name the table.
3. Run Steps 1, 2, 3 in Advanced Hunting against that table.
4. Run Steps 4, 5, 6 to confirm root cause and write your closeout
   using the structure at the bottom of the playbook.

If you have the workbook imported, replace steps 2 through 5 with
"set the parameters at the top of the workbook" and read down the
page.

## Prerequisites

| Capability | Used by |
|---|---|
| Sentinel reader on the target workspace | Step 0 (Usage table is in Sentinel, not Defender XDR) |
| Microsoft Defender XDR Advanced Hunting access | Steps 1 through 6, plus every query in the workbook |
| Defender XDR data connector enabled on the Sentinel workspace | Workbook only (so the `Device*` tables land in Log Analytics where the workbook reads them) |
| A text editor for the KQL files | VS Code is ideal. Notepad works. |

The KQL files themselves have no other dependencies. They reference
only built in tables (`Usage` for Step 0, `Device*` and a few
Sentinel native tables for the rest).

## Glossary

A short reference so the rest of the package reads consistently.

- **DataType**: the column the Sentinel `Usage` table uses for the
  table name. Same value as the table you would query (e.g.
  `DeviceFileEvents`).
- **Spike window**: the date range the spike covers. Set this to the
  first and last day of elevated volume, or first day and today if
  the spike is ongoing.
- **Baseline window**: the comparable period of normal volume. The
  KQL files default to the 7 days immediately before the spike. The
  workbook lets you pick any window with a time picker.
- **Per day normalisation**: dividing the windowed total by the
  number of days in the window so a 3 day spike can be compared
  directly to a 7 day baseline.
- **ActionType**: the second level classifier on the `Device*` tables
  (`FileCreated`, `ProcessCreated`, `AntivirusScanCompleted`, etc.).
  One ActionType usually drives most of any spike on those tables.
- **Initiator triplet**: the three columns Step 3 groups by, which
  uniquely identify a chain of activity on a device:
  `InitiatingProcessParentFileName` (grandparent of the action),
  `InitiatingProcessFileName` (the binary that did the action), and
  `InitiatingProcessVersionInfoCompanyName` (signing publisher).
- **Vendor and product attribution**: the workbook joins each row
  from Step 3 and Step 5 against the binary metadata
  (`InitiatingProcessVersionInfoCompanyName` and `ProductName`) so
  the table shows publisher and product name next to each binary
  even when only the file name is interesting.
- **Fleet share**: percentage of the total spike events that a
  single device accounts for. High fleet share on one device means
  the device is broken. Low fleet share spread across thousands of
  devices means a fleet wide rollout.
- **Closeout**: the three part write up you produce at the end of an
  investigation. Outcome (one sentence), evidence chain (which queries
  showed what), brief language (plain English for leadership).

## How the workbook and the KQL files relate

The workbook does not invent any new queries. Every query in it is a
direct port of the KQL file with the same step number, with three
differences:

1. **Parameters instead of literals**. The date block is replaced
   with workbook parameters (`{SpikeRange}` and `{BaselineRange}`)
   so the picker UI drives the dates.
2. **Per day normalisation everywhere**. Both spike and baseline are
   divided by their day count so any two windows are directly
   comparable.
3. **Attribution join**. Steps 3 and 5 join against a small lookup
   that pulls vendor and product name from the binary metadata so
   the table shows the publisher next to the file name.

If you want to understand a workbook query, open the matching
numbered `.kql` file. The intent is identical.

## Anomaly section in the workbook

The workbook starts with an extra section that does not exist as a
standalone `.kql` file: a 30 day anomaly scan across every billable
table using `series_decompose_anomalies`. It surfaces tables that
spiked abruptly in a single day and were ignored.

This is intentionally narrow. The scan catches abrupt one day jumps
against a linefit baseline. A sustained, multi day rise (the
DeviceFileEvents pattern in this lab is a good example) is absorbed
into the baseline and scores below the alerting threshold. Sustained
rises are what Steps 0 through 3 are designed to catch, so the two
views are complementary, not duplicative.

There are also two trivia guards in the anomaly query:

- `MinDailyVolume = 100` filters out near zero tables that read as
  100 percent anomalies on a 0 row to 1 row jump.
- `Score >= 3.0` is the standard `series_decompose_anomalies` cutoff.

If the anomaly section returns zero rows, that is the healthy state:
no abrupt one day spikes worth chasing. Steps 0 through 3 still
apply.

## Limitations and known gaps

- **Anomaly section only catches abrupt one day spikes**. Sustained
  multi day rises do not score above the threshold. Use Steps 0
  through 3 for those, which is what they are designed for.
- **The workbook needs the Defender XDR data connector**. Without
  the connector, the `Device*` tables are empty in Log Analytics and
  the workbook returns no rows. The standalone `.kql` files still
  work in Advanced Hunting in that case.
- **Step 0 reads the `Usage` table**, which only exists in Sentinel,
  not in Defender XDR Advanced Hunting. Run it in Sentinel Logs.
- **`series_decompose_anomalies` is sensitive to gaps**. A table
  that was paused for a day and resumed reads as an anomaly. Treat
  scores between 3 and 5 with care.

## When NOT to use this package

- For cost forecasting or chargeback reports. Use the Sentinel
  Workspace usage workbook in the Azure portal.
- For real time alerting on volume changes. Use scheduled analytics
  rules.
- For investigating a specific security alert or incident. Use the
  alert page in Defender XDR.

This package is for one specific case: a table volume spiked,
leadership wants to know why, and you have a short window to find
out and write it up.

## Closeout template

Every investigation finishes with this structure. Paste it into the
ticket or brief:

```
Outcome
-------
<one sentence: what is the spike, was anything broken, what action
follows?>

Evidence chain
--------------
- Step 0 (00_what_table_spiked.kql): <which table led, by how much>
- Step 1 (01_when_spiked_timechart.kql): <when it started, ongoing or not>
- Step 2 (02_top_actiontypes.kql): <which ActionType dominated>
- Step 3 (03_spike_vs_baseline.kql): <named binary and parent>
- Step 4 (04_top_destinations.kql): <where the binary wrote / connected>
- Step 5 (05_device_concentration.kql): <fleet wide or a few hosts>
- Step 6 (06_drill_processtree.kql): <full parent chain on one host>

Brief language
--------------
<plain English paragraph for leadership: no KQL, name the activity,
state whether action is required.>
```

## Layout of a typical investigation

A normal investigation ends in three to fifteen minutes of click time
plus query runtime. The walltime is dominated by KQL queries against
big tables. Expect:

- Step 0 against `Usage`: a few seconds.
- Steps 1 and 2 hourly against one `Device*` table over 10 days:
  10 to 30 seconds each.
- Step 3 over 10 days grouped by three columns: 20 to 90 seconds.
- Steps 4 through 6 narrowed by binary or device: a few seconds each.

If a query times out, narrow the spike window first, then the table
filter, then add an `ActionType` prefilter.

## Repo, license, and contribution

This folder lives in the public `johnB007/Defender_XDR` repository
on GitHub under `Workbooks/`. Pull requests are welcome.
