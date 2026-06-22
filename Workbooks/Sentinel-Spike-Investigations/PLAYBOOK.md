# Playbook : investigating a Sentinel ingestion spike

Work the seven KQL files in order. Each one takes about a minute to
edit and run. After each query, the section below tells you what to
look for, how to read the output, and which file to open next.

Before you start, open two browser tabs:

- Advanced Hunting:
  `https://security.microsoft.com/v2/advanced-hunting`
- Sentinel Logs in the Azure portal (for Step 0, which reads the
  `Usage` table that only exists in Sentinel).

If you also have the workbook imported, you can drive the same steps
from `Sentinel : Workbooks : Spike Investigator` instead of pasting
KQL by hand. See [WORKBOOK.md](WORKBOOK.md). This
playbook stays useful as the reference for what each step does and
how to read the output.

## The one knob you change

Every numbered query file has a date block at the top:

```kql
let spikeStart = datetime(2026-06-09);
let spikeEnd   = datetime(2026-06-12);
let baseEnd    = spikeStart;
let baseStart  = baseEnd - 7d;
```

Set `spikeStart` to the first day you saw elevated volume. Set
`spikeEnd` to the last day, or to today if the spike is ongoing.
Leave the other two lines alone. Repeat this once per file as you
open it. Some files also have a `table name` line you swap if the
spike is in a `Device*` table other than `DeviceEvents`.

## Step 0 : name the table that spiked

**File**: [kql/00_what_table_spiked.kql](kql/00_what_table_spiked.kql)
**Where to run**: Sentinel Logs in the Azure portal. The `Usage`
table lives in Sentinel and is not available in Defender XDR
Advanced Hunting.

**What you edit**: the date block at the top.

**What the query returns**: every billable `DataType` with four
columns:

- `BaselinePerDayGB`: average GB per day during the prior 7 days.
- `SpikePerDayGB`: average GB per day during the spike window.
- `DeltaPerDayGB`: the difference, top of the table.
- `RatioVsBaseline`: spike per day divided by baseline per day. A
  ratio of `2.0` means double the normal volume. The query returns
  the spike value itself when the baseline is zero so a brand new
  table reads as its own GB per day.

**How to read it**:

- The top row is the table that grew the most in absolute GB. That
  is the table to investigate.
- A ratio above `1.5` is interesting. Below that is noise.
- A baseline of `0.0` plus a non zero spike means a brand new table
  appeared. Treat it as a connector change rather than a spike.

**What you do next**: write down the `DataType` name. If the top row
is a `Device*` table, continue to Step 1. If it is one of the
Sentinel native tables (`SecurityEvent`, `Syslog`, `CommonSecurityLog`,
`AzureDiagnostics`, `Heartbeat`, custom `*_CL`), skip Step 2 because
those tables do not have an `ActionType` column. Steps 1 and 3 still
apply.

## Step 1 : pin the exact hour the spike started

**File**: [kql/01_when_spiked_timechart.kql](kql/01_when_spiked_timechart.kql)
**Where to run**: Advanced Hunting (or Sentinel Logs, either works).

**What you edit**:

- The date block at the top.
- The table name on the first table line below the let block. Swap
  `DeviceEvents` for the DataType from Step 0 if it is different.

**What the query returns**: an hourly bin of event counts across the
spike window plus 7 days of baseline. Render as a line chart.

**How to read it**:

- Hover the chart and find the exact hour the line jumps. Write it
  down. You will use it for Step 6.
- Note whether the curve is back to baseline yet or still elevated.
  Active spikes need an immediate decision. Concluded spikes are
  cleanup write ups.
- A flat curve at a new elevation is a step change, usually a
  configuration push (new ActionTypes captured, new DCR, agent
  update). A bell curve is a transient (Patch Tuesday, scheduled AV
  scan, signature push).

**What you do next**: if the table has an `ActionType` column
(any `Device*` table), continue to Step 2. Otherwise skip to Step 3.

## Step 2 : find the noisy ActionType

**File**: [kql/02_top_actiontypes.kql](kql/02_top_actiontypes.kql)
**Where to run**: Advanced Hunting.

**What you edit**:

- The date block.
- The table name if you are on a Device* table other than
  `DeviceEvents`.

**What the query returns**: ranked list of ActionType values during
the spike with three columns:

- `Events`: count.
- `Devices`: distinct devices that produced the ActionType.
- `EventsPerDevice`: events divided by devices.

**How to read it**:

- One or two ActionTypes usually account for the majority of the
  spike (`FileCreated`, `ProcessCreated`,
  `AntivirusScanCompleted`, `RegistryValueSet`, etc.). Note them.
- A high `EventsPerDevice` on a small `Devices` number is a single
  device problem. A low `EventsPerDevice` across thousands of
  devices is a fleet wide rollout.
- The combination `FileCreated` + thousands of devices + balanced
  per device count is almost always Patch Tuesday or a Defender
  platform update.

**What you do next**: continue to Step 3. Optionally feed the top
ActionType into the `actionFilter` line in Step 3 for cleaner
results.

## Step 3 : name the binary driving the spike

This is the most important query in the playbook. The top row of
the output almost always names the binary that is responsible for
the extra volume.

**File**: [kql/03_spike_vs_baseline.kql](kql/03_spike_vs_baseline.kql)
**Where to run**: Advanced Hunting.

**What you edit**:

- The date block.
- The table name if needed.
- Optional: if Step 2 named a dominant ActionType, set the
  `actionFilter` line to that ActionType to narrow the comparison.
- Tune the `where Spike > 10000` threshold. Raise it to `100000`
  or `1000000` on very high volume tables so the result is not
  flooded with noise rows.

**What the query returns**: rows grouped by the initiator triplet
(`Parent`, `Init`, `Company`) with five numeric columns:

- `Baseline`: events in the prior 7 days for this triplet.
- `Spike`: events in the spike window for this triplet.
- `Delta`: spike minus baseline.
- `Ratio`: spike divided by baseline. Returns the spike value when
  baseline is zero so brand new activity is visible.

**How to read it**:

- Sort by `Delta` descending. The top five rows are the candidate
  culprits.
- Read the `Company` column. Microsoft Corporation rows are almost
  always servicing or Defender activity. Third party publisher rows
  are agent activity. Blank Company values are usually scripts or
  custom binaries.
- Read the `Parent` and `Init` pair. Known servicing pairs include
  `services.exe` to `TrustedInstaller.exe`, then
  `TrustedInstaller.exe` to `tiworker.exe`. Known Defender pairs
  include `services.exe` to `MsMpEng.exe`. Known third party agent
  pairs include the agent service spawning its worker process.

**What you do next**: read the top one or two `Init` values. A
recognised servicing or agent binary usually points straight at the
cause. Continue to Step 4 for confirmation.

**Worked example from the lab**: the top row was
`Init = MsMpEng.exe`, `Parent = services.exe`,
`Company = microsoft corporation`, `Delta = 1.2M`. This is the
Microsoft Defender platform and signature update pattern. The
investigation closed at this step.

## Step 4 : confirm with destination data

**File**: [kql/04_top_destinations.kql](kql/04_top_destinations.kql)
**Where to run**: Advanced Hunting.

**What you edit**: the file has one block active at the top
(`DeviceFileEvents`) and several commented blocks for other tables.
Uncomment the block that matches your spike table and comment the
others. Then set the date block and put the suspect binary name
from Step 3 into the `initFilter` line.

**What the query returns**: depends on the block:

- `DeviceFileEvents` block: top folder roots written or modified
  by the suspect binary, with sample file names and the command
  line that started the binary.
- `DeviceProcessEvents` block: top command lines.
- `DeviceNetworkEvents` block: top remote IP + port pairs with a
  sample URL.
- `DeviceRegistryEvents` block: top registry key roots and
  ActionType pairs.
- `DeviceImageLoadEvents` block: top DLLs loaded with the signers.

**How to read it**:

- Servicing stack writes show up under `c:\windows\winsxs\`,
  `c:\windows\softwaredistribution\`, and `c:\windows\system32\`.
- Defender platform updates show up under
  `c:\programdata\microsoft\windows defender\`.
- Third party agent reinstalls show up under `c:\program files\`
  or `c:\programdata\<vendor>\`.
- Backup agent activity shows up under `c:\windows\system32\` for
  the VSS provider and the backup vendor folder for the snapshot
  metadata.

**What you do next**: continue to Step 5.

## Step 5 : decide fleet wide or a few broken devices

**File**: [kql/05_device_concentration.kql](kql/05_device_concentration.kql)
**Where to run**: Advanced Hunting.

**What you edit**: date block, table name, and optional suspect
binary filter near the top.

**What the query returns**: top 25 devices by event count during
the spike with three columns:

- `Events`: count on this device.
- `DistinctInitiators`: number of distinct binaries on this device
  that produced events in the window.
- `FleetShare`: percent of total spike events accounted for by
  this device.

**How to read it**:

- Many devices, each with low `FleetShare`: fleet wide rollout.
  Patch Tuesday, Defender platform update, AV scan window, MDM
  enrolment wave. Nothing to fix at the device level.
- Five devices, each with high `FleetShare`: a small number of
  runaway agents. Open a ticket on those device names. Treat
  every device above 5 percent fleet share as a candidate for
  individual investigation.
- One device with 80 percent fleet share: a single broken host.
  Go straight to Step 6 with that device name.

**What you do next**: if the pattern is fleet wide and Step 3
named a recognised binary, you are done. Write the closeout using
the structure at the bottom of this playbook. If the pattern is the
runaway device case, continue to Step 6 with one of the device
names.

## Step 6 : prove root cause on a single device

**File**: [kql/06_drill_processtree.kql](kql/06_drill_processtree.kql)
**Where to run**: Advanced Hunting.

**What you edit**: at the top of the file, set:

- `device`: a device name from Step 5.
- `suspect`: a process name from Step 3 (or empty string to drop
  the filter and see all activity).
- `windowStart`: the hour the spike began on that device.
- `windowEnd`: defaults to `windowStart + 3h`.

**What the query returns**: the full parent chain for the suspect
process on that device in the window, projected to:

- `Timestamp`
- `Grandparent` = `InitiatingProcessParentFileName`
- `Parent` = `InitiatingProcessFileName`
- `Child` = `FileName`
- `ChildCmd` = `ProcessCommandLine`
- account names and folder paths for both initiator and child.

**How to read it**:

- Windows servicing call stack: `services.exe` to
  `TrustedInstaller.exe` to `tiworker.exe`.
- Defender platform update: `services.exe` to `MsMpEng.exe`, with
  child `MsMpEng.exe`, `MpCmdRun.exe`, `MpDefenderCoreService.exe`.
- Third party agent: the vendor service spawning its worker
  process repeatedly, often once per minute.
- Scripted custom workload: `powershell.exe` or `cmd.exe` as the
  parent, with the same command line repeating.

**What you do next**: write your closeout using the structure
below.

## What "done" looks like

A closeout has three parts. Paste them into the ticket in this
order.

### 1. Outcome

One sentence. State what the spike is and whether any action
follows.

> Spike on `DeviceEvents` between 2026-06-09 and 2026-06-12 is the
> Microsoft Defender platform and signature update wave following
> Patch Tuesday. No action required.

### 2. Evidence chain

Three to five bullets. Reference the file names so a reviewer can
rerun the queries.

> - `00_what_table_spiked.kql`: `DeviceEvents` led at +1.8 GB per
>   day delta.
> - `01_when_spiked_timechart.kql`: spike started 2026-06-09 04:00 UTC.
> - `02_top_actiontypes.kql`: `AntivirusScanCompleted` accounted
>   for 78 percent of the volume.
> - `03_spike_vs_baseline.kql`: top row was `MsMpEng.exe` under
>   `services.exe` with `Delta = 1.2M`.
> - `05_device_concentration.kql`: 1,420 distinct devices with no
>   single device above 1 percent fleet share. Fleet wide.

### 3. Brief language

A short paragraph for leadership in plain English. No KQL.

> The recent ingestion spike was caused by the regular Microsoft
> Defender platform and signature update wave that follows Patch
> Tuesday. Activity is concentrated on the Defender engine
> (`MsMpEng.exe`) across the entire monitored fleet and is
> expected. Volume is returning to baseline as the wave completes.
> No tuning, no rule changes, and no device action are required.

## Anti patterns

Things that look like shortcuts but cost time:

- **Skipping Step 0** because you "already know which table spiked".
  The `Usage` table is the only authoritative ranking. Sometimes
  the alert names the wrong table.
- **Setting the spike window too wide**. A 30 day window dilutes
  every comparison. Keep the spike window to the actual elevated
  days plus or minus one.
- **Setting the baseline window too short**. Five days is too
  noisy. Seven to fourteen days is the sweet spot. The workbook
  uses 14 by default.
- **Lowering the `Spike > 10000` threshold in Step 3 too far**.
  On high volume tables, 10000 is already too low. Raise it before
  you lower it.
- **Reading `Ratio` without `Delta`**. A row with `Spike = 5,
  Baseline = 1, Ratio = 5.0` is noise. Always sort by `Delta` first.
- **Calling Patch Tuesday "an incident"**. Well understood patterns
  should close fast without organisational noise.

## Where this leaves you

After Step 6 you have:

- A named table.
- A named binary.
- A named publisher.
- A named pattern or a custom closeout.
- An evidence chain that any reviewer can reproduce in minutes.

That is enough to close the alert, file the brief, and move on.
