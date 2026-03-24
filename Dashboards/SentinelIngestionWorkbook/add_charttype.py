import json, shutil, os

PATH = os.path.join(os.path.dirname(__file__), "SentinelIngestionWorkbook.json")
shutil.copy(PATH, PATH + ".charttype.bak")

with open(PATH) as f:
    wb = json.load(f)

# 1. Add ChartType dropdown parameter
CHART_PARAM = {
    "id": "a1b2c3d4-0003-0003-0003-000000000003",
    "version": "KqlParameterItem/1.0",
    "name": "ChartType",
    "label": "Chart Type",
    "type": 10,
    "isRequired": True,
    "typeSettings": {"additionalResourceOptions": [], "showDefault": False},
    "jsonData": (
        '[{"value":"barchart","label":"Bar (stacked)","selected":true},'
        '{"value":"linechart","label":"Line"},'
        '{"value":"areachart","label":"Area"},'
        '{"value":"piechart","label":"Pie"},'
        '{"value":"scatterchart","label":"Scatter"}]'
    )
}

params = wb["items"][0]["content"]["parameters"]
if not any(p["name"] == "ChartType" for p in params):
    params.insert(1, CHART_PARAM)
    print("Added ChartType parameter")
else:
    print("ChartType already present, skipping")

# 2. Wire {ChartType} into the three overview bar charts only
TARGET_CHARTS = {"chart-First", "chart-Second", "chart-Fifth"}

def patch_vis(node):
    if isinstance(node, dict):
        if node.get("name") in TARGET_CHARTS:
            old = node.get("content", {}).get("visualization")
            node["content"]["visualization"] = "{ChartType}"
            print(f"Patched {node['name']}: {old!r} -> '{{ChartType}}'")
        for v in node.values():
            patch_vis(v)
    elif isinstance(node, list):
        for c in node:
            patch_vis(c)

patch_vis(wb)

with open(PATH, "w", encoding="utf-8") as f:
    json.dump(wb, f, indent=2, ensure_ascii=False)

print(f"Done — {os.path.getsize(PATH):,} bytes")
