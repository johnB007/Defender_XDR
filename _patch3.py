import json, re, io, os, sys
from pathlib import Path

WB = Path('Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook')
ARM = Path('Dashboards/Network-Security-Operations-Center/azuredeploy.json')

KPI_NEW = open(r'C:\Users\jobarbar\AppData\Roaming\Code\User\_kqltmp\kpi-new.kql','r',encoding='utf-8').read()
TIDOM_NEW = open(r'C:\Users\jobarbar\AppData\Roaming\Code\User\_kqltmp\tidom-new.kql','r',encoding='utf-8').read()

def patch_query(name, q):
    if name == 'correlation-kpi-tiles':
        return KPI_NEW
    if name == 'correlation-ti-domain-matches':
        # Replace let TIDom = ThreatIntelIndicators ... up through 'IndicatorId = tostring(Id);' (first occurrence)
        m = re.search(r'let TIDom = ThreatIntelIndicators[\s\S]*?IndicatorId = tostring\(Id\)\s*;', q)
        if not m:
            raise SystemExit('TIDom block not found')
        return q[:m.start()] + TIDOM_NEW.rstrip() + q[m.end():]
    return q

def walk(node):
    if isinstance(node, dict):
        nm = node.get('name')
        cont = node.get('content')
        if nm in ('correlation-kpi-tiles','correlation-ti-domain-matches') and isinstance(cont, dict) and 'query' in cont:
            cont['query'] = patch_query(nm, cont['query'])
            print(f'Patched {nm}')
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)

# 1) workbook
wb_text = WB.read_text(encoding='utf-8-sig')
wb = json.loads(wb_text)
walk(wb)
WB.write_text(json.dumps(wb, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

# 2) ARM
arm_text = ARM.read_text(encoding='utf-8-sig')
arm = json.loads(arm_text)
def walk_arm(node):
    if isinstance(node, dict):
        if 'serializedData' in node and isinstance(node['serializedData'], str):
            inner = json.loads(node['serializedData'])
            walk(inner)
            node['serializedData'] = json.dumps(inner, ensure_ascii=False)
        for v in node.values():
            walk_arm(v)
    elif isinstance(node, list):
        for v in node:
            walk_arm(v)
walk_arm(arm)
ARM.write_text(json.dumps(arm, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print('Saved both files')
