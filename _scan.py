import json, re, pathlib
wb_path = pathlib.Path("Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook")
wb = json.loads(wb_path.read_text(encoding="utf-8"))

def walk(items, parent=""):
    for it in items:
        nm = it.get("name","")
        if it.get("type") == 1:
            c = it.get("content",{})
            txt = c.get("json","")
            print(f"--- {nm} ---")
            print(txt[:400])
            print()
        if "items" in it.get("content",{}):
            walk(it["content"]["items"], nm)
        for grp in it.get("content",{}).get("tabs",[]) or []:
            pass

walk(wb.get("items", []))
