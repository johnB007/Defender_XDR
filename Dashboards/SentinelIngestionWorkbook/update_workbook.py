import json
import copy

INPUT  = r"C:\Users\jobarbar\Defender_XDR\Dashboards\SentinelIngestionWorkbook\SentinelIngestionWorkbook.json"
OUTPUT = INPUT  # overwrite in place

with open(INPUT, "r", encoding="utf-8") as f:
    wb = json.load(f)

# ── Transform Quick-Reference note (markdown) to insert at the top of each device breakout tab ──
TRANSFORM_NOTE = {
    "type": 1,
    "content": {
        "json": (
            "#### \U0001f527 Transform Quick Reference — Filtering Fields for Ingestion Transforms\n"
            "Use these three fields from the drilldown tables below to build workspace transforms that drop noisy events:\n\n"
            "| # | Field | Scope | Example KQL Filter |\n"
            "|---|-------|-------|--------------------|\n"
            "| 1 | **InitiatingProcessFolderPath** | Drops all events from a specific installed application path | "
            "`where InitiatingProcessFolderPath !contains \"C:\\\\Program Files\\\\NoisyApp\"` |\n"
            "| 2 | **InitiatingProcessFileName** | More targeted — drops events from a specific executable regardless of install location | "
            "`where InitiatingProcessFileName != \"noisyagent.exe\"` |\n"
            "| 3 | **InitiatingProcessVersionInfoCompanyName** | Broadest — drops everything from an entire vendor | "
            "`where InitiatingProcessVersionInfoCompanyName != \"Noisy Vendor Inc.\"` |\n\n"
            "> **Tip:** Click a vendor row, then use the *Process Detail* table to identify the exact values to plug into your transform."
        ),
        "style": "info"
    },
    "name": ""  # will be set per-tab below
}

# The 3 required fields that must be in every drilldown process-detail query
REQUIRED_FIELDS = [
    "InitiatingProcessFolderPath",
    "InitiatingProcessFileName",
    "InitiatingProcessVersionInfoCompanyName",
]

# Map of top-level item names to their tab identifiers (for naming the note)
DEVICE_TABS = {
    "Device File Events":       "Third",
    "Device Network Events":    "Fourth",
    "Device Process Events":    "Sixth",
    "Device Registry Events":   "Seventh",
    "Device Image Load Events": "Eighth",
    "Device Events":            "Ninth",
}

changes_made = []

for item in wb["items"]:
    if item.get("type") != 12:
        continue
    tab_name = item.get("name", "")
    if tab_name not in DEVICE_TABS:
        continue

    tab_id = DEVICE_TABS[tab_name]
    sub_items = item["content"]["items"]

    # ── 1. Insert the transform quick-reference note right after the first barchart ──
    # Find the first chart (type 3 with visualization=barchart) and insert after it
    already_has_note = any(
        si.get("type") == 1 and "Transform Quick Reference" in si.get("content", {}).get("json", "")
        for si in sub_items
    )
    if not already_has_note:
        note = copy.deepcopy(TRANSFORM_NOTE)
        note["name"] = f"transform-ref-{tab_id}"

        # Insert after the first barchart item
        insert_idx = None
        for idx, si in enumerate(sub_items):
            if si.get("type") == 3 and si.get("content", {}).get("visualization") == "barchart":
                insert_idx = idx + 1
                break
        if insert_idx is not None:
            sub_items.insert(insert_idx, note)
            changes_made.append(f"  Added transform quick-reference note to '{tab_name}' tab at position {insert_idx}")

    # ── 2. Verify & fix: ensure all 3 fields appear in drilldown process-detail queries ──
    for si in sub_items:
        if si.get("type") != 3:
            continue
        si_name = si.get("name", "")
        if "drilldown" not in si_name or "process" not in si_name:
            continue

        query = si["content"].get("query", "")
        label_settings = si["content"].get("gridSettings", {}).get("labelSettings", [])
        existing_col_ids = {ls["columnId"] for ls in label_settings}

        for field in REQUIRED_FIELDS:
            # Check query
            if field not in query:
                changes_made.append(f"  WARNING: '{field}' missing from query in '{si_name}' ({tab_name}) — adding to 'by' clause")
                # Add to the 'by' clause (before the last line "| order by")
                query = query.replace(
                    "| order by EventCount desc",
                    f"       {field},\n| order by EventCount desc"
                )
                # Also need to add to the 'by' line if it's after the last existing field
                si["content"]["query"] = query

            # Check labelSettings for the field
            if field not in existing_col_ids:
                label_map = {
                    "InitiatingProcessFolderPath": "Process Folder Path",
                    "InitiatingProcessFileName": "Process File Name",
                    "InitiatingProcessVersionInfoCompanyName": "Company Name",
                }
                label_settings.append({
                    "columnId": field,
                    "label": label_map[field]
                })
                changes_made.append(f"  Added label for '{field}' in '{si_name}' ({tab_name})")

with open(OUTPUT, "w", encoding="utf-8") as f:
    json.dump(wb, f, indent=2, ensure_ascii=False)

print("=== Changes Summary ===")
if changes_made:
    for c in changes_made:
        print(c)
else:
    print("No changes needed — all fields already present.")
print(f"\nFile written: {OUTPUT}")
