import json, pathlib, re

wb_path = pathlib.Path("Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook")
wb = json.loads(wb_path.read_text(encoding="utf-8"))

NEW_KPI = pathlib.Path("_kqltmp/kpi-v4.kql").read_text(encoding="utf-8")

# One-sentence banner replacements (preserves heading then 1 sentence).
BANNERS = {
  "banner-header": "# Network Security Operations Center\n\nUnified NSOC view across NetFlow, Zeek, firewall, DNS, MDE, and threat intel — search by IP, domain, or MAC below.",
  "text-executive-header": "## Executive Security Summary\n\nReal-time network security posture rolled up from every connected data source.",
  "text-dns-header": "## DNS Intelligence Dashboard\n\nPi-hole sinkhole query analysis with suspicious domain and DNS tunneling detection.",
  "text-netflow-header": "## NetFlow Deep Dive Analytics\n\nBandwidth, top talkers, protocol distribution, and flow-pattern analytics from NetFlow_CL.",
  "text-firewall-header": "## WiFi / LAN Details\n\nSwitch and AP health plus MDE-enriched WiFi visibility (SSID, identity, signal, rogue and anomaly detection).",
  "text-zeek-header": "## Zeek IDS Deep Analysis\n\nProtocol analysis and behavioral IDS analytics from bridge-mode Zeek capture (Sinkhole → Cribl → Sentinel).",
  "text-correlation-header": "## Threat Correlation\n\nCross-source TI correlation: MDTI + abuse.ch IOCs vs NetFlow, Zeek, Firewall, DNS, MDE.",
  "text-hunting-header": "## Threat Hunting\n\nProactive hunts for beaconing, lateral movement, and data-exfiltration indicators.",
  "text-worldmap-header": "## Global Threat Heat Map\n\nLog-scaled geo heat map of external threat sources correlated across all Sentinel and XDR data.",
  "text-investigate-header": "## Investigation Portal\n\nDeep-dive across all sources for IP=`{SearchIP:value}` Domain=`{SearchDomain:value}` MAC=`{SearchMAC:value}` (blank = all).",
}

KPI_NAMES = {"correlation-kpi-tiles","query-correlation-kpi-tiles"}

def patch(items):
    for it in items:
        nm = it.get("name","")
        # Banners
        if it.get("type") == 1 and nm in BANNERS:
            it["content"]["json"] = BANNERS[nm]
        # KPI tile
        if it.get("type") == 3 and ("kpi" in nm.lower() and "correlation" in nm.lower()):
            c = it["content"]
            c["query"] = NEW_KPI
            viz = c.get("visualization")
            if viz == "tiles":
                ts = c.setdefault("tileSettings", {})
                ts["titleContent"] = {"columnMatch":"Column","formatter":1}
                ts["leftContent"] = {
                    "columnMatch":"Value",
                    "formatter":12,
                    "formatOptions":{"palette":"auto"}
                }
                # secondary content shows Detail
                ts["secondaryContent"] = {"columnMatch":"Detail","formatter":1}
                # remove subtitle
                ts.pop("subtitleContent", None)
                ts["showBorder"] = True
        # recurse
        sub = it.get("content",{}).get("items")
        if sub: patch(sub)

patch(wb.get("items", []))
wb_path.write_text(json.dumps(wb, indent=2), encoding="utf-8")
print("workbook patched")

# sync azuredeploy.json
adp = pathlib.Path("Dashboards/Network-Security-Operations-Center/azuredeploy.json")
arm = json.loads(adp.read_text(encoding="utf-8"))
def find_resources(obj):
    if isinstance(obj, dict):
        if "resources" in obj and isinstance(obj["resources"], list):
            yield from obj["resources"]
        for v in obj.values():
            yield from find_resources(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from find_resources(v)

serialized = json.dumps(wb)
count = 0
for r in find_resources(arm):
    if isinstance(r, dict) and r.get("type","").lower().endswith("workbooks"):
        props = r.get("properties",{})
        if "serializedData" in props:
            props["serializedData"] = serialized
            count += 1
print(f"sync serializedData: {count}")
adp.write_text(json.dumps(arm, indent=2), encoding="utf-8")
