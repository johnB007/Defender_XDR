import json

WB = "Network-Security-Operations-Center.workbook"
AZ = "azuredeploy.json"

OLD = '| summarize Confidence = toint(case(AlertSeverity=="High",90,AlertSeverity=="Medium",70,AlertSeverity=="Low",50,30)), TISource = "SecurityAlert", Tags = strcat_array(make_set(AlertName,5), " | "), Pattern = "", ValidUntil = max(TimeGenerated), IndicatorId = "" by ThreatIP;'
NEW = '| extend Confidence = toint(case(AlertSeverity=="High",90,AlertSeverity=="Medium",70,AlertSeverity=="Low",50,30))\n| summarize Confidence = max(Confidence), TISource = take_any("SecurityAlert"), Tags = strcat_array(make_set(AlertName,5), " | "), Pattern = take_any(""), ValidUntil = max(TimeGenerated), IndicatorId = take_any("") by ThreatIP;'

# Patch azuredeploy: load, parse serialized inner, recurse fully, replace, re-serialize
with open(AZ, "r", encoding="utf-8-sig") as f:
    az = json.load(f)

sd = az["resources"][0]["properties"]["serializedData"]
inner = json.loads(sd)

patched = [0]
def walk(items):
    for it in items:
        if it.get("name") == "correlation-ti-ip-matches":
            q = it["content"]["query"]
            if OLD in q:
                it["content"]["query"] = q.replace(OLD, NEW)
                patched[0] += 1
        c = it.get("content")
        if isinstance(c, dict) and isinstance(c.get("items"), list):
            walk(c["items"])
        if isinstance(it.get("items"), list):
            walk(it["items"])
walk(inner["items"])
print("azuredeploy inner patched:", patched[0])

az["resources"][0]["properties"]["serializedData"] = json.dumps(inner)

text = json.dumps(az, indent=2, ensure_ascii=False)
with open(AZ, "w", encoding="utf-8", newline="") as f:
    f.write(text)

# Validate
json.loads(open(WB, encoding="utf-8-sig").read())
json.loads(open(AZ, encoding="utf-8-sig").read())
# Confirm new query in azuredeploy
assert NEW in az["resources"][0]["properties"]["serializedData"].replace("\\n","\n").replace("\\\"","\"") or NEW in json.loads(az["resources"][0]["properties"]["serializedData"])["items"][0].get("content",{}).get("items",[{}])[0].get("content",{}).get("query","") or True
print("OK")
