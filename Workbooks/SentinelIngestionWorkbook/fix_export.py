import json

with open('SentinelIngestionWorkbook.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

fixed = 0

def fix_item(item):
    global fixed
    if not isinstance(item, dict):
        return
    if 'gridSettings' in item:
        gs = item['gridSettings']
        if isinstance(gs, dict):
            if not gs.get('showExportToExcel', False):
                gs['showExportToExcel'] = True
                fixed += 1
            if 'exportAllFields' not in gs:
                gs['exportAllFields'] = True
    for v in item.values():
        if isinstance(v, dict):
            fix_item(v)
        elif isinstance(v, list):
            for el in v:
                if isinstance(el, dict):
                    fix_item(el)

fix_item(data)

with open('SentinelIngestionWorkbook.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Fixed {fixed} gridSettings blocks")

# Verify
with open('SentinelIngestionWorkbook.json', 'r', encoding='utf-8') as f:
    c = f.read()
print(f"showExportToExcel count: {c.count('showExportToExcel')}")
print(f"exportAllFields count: {c.count('exportAllFields')}")
print(f"gridSettings count: {c.count('gridSettings')}")
