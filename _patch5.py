import json, pathlib
kql = pathlib.Path("_kqltmp/kpi-v3.kql").read_text(encoding="utf-8").rstrip()

def patch_tile(o):
    n = 0
    if isinstance(o, dict):
        if o.get("name") == "correlation-kpi-tiles" and "content" in o:
            o["content"]["query"] = kql
            ts = o["content"].get("tileSettings", {})
            lc = ts.get("leftContent", {})
            lc["formatter"] = 1
            if "formatOptions" in lc:
                del lc["formatOptions"]
            n += 1
        for v in o.values():
            n += patch_tile(v)
    elif isinstance(o, list):
        for v in o:
            n += patch_tile(v)
    return n

wb_path = pathlib.Path("Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook")
arm_path = pathlib.Path("Dashboards/Network-Security-Operations-Center/azuredeploy.json")

wb = json.loads(wb_path.read_text(encoding="utf-8"))
n1 = patch_tile(wb)
print(f"workbook tiles patched: {n1}")
assert n1 >= 1
wb_path.write_text(json.dumps(wb, indent=2), encoding="utf-8")

arm = json.loads(arm_path.read_text(encoding="utf-8"))
def walk(o):
    n = 0
    if isinstance(o, dict):
        if "serializedData" in o and isinstance(o["serializedData"], str):
            try:
                inner = json.loads(o["serializedData"])
            except Exception:
                inner = None
            if isinstance(inner, (dict, list)):
                m = patch_tile(inner)
                if m:
                    o["serializedData"] = json.dumps(inner)
                    n += m
        for v in o.values():
            n += walk(v)
    elif isinstance(o, list):
        for v in o:
            n += walk(v)
    return n
n2 = walk(arm)
print(f"ARM tiles patched: {n2}")
assert n2 >= 1
arm_path.write_text(json.dumps(arm, indent=2), encoding="utf-8")
print("DONE")
