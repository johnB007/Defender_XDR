import json, re

f = 'SentinelIngestionWorkbook.json'
d = json.load(open(f, 'r', encoding='utf-8'))

# Check 1: tables missing exportAllFields
print('=== Tables missing exportAllFields ===')
for i, item in enumerate(d['items']):
    if item.get('type') != 12:
        continue
    name = item.get('name', '')
    for j, si in enumerate(item.get('content', {}).get('items', [])):
        if si.get('type') != 3:
            continue
        gs = si.get('content', {}).get('gridSettings', {})
        vis = si.get('content', {}).get('visualization', '')
        sn = si.get('name', '')
        if vis == 'table' and not gs.get('exportAllFields'):
            print(f'  [{name}] sub[{j}] name={sn}')

# Check 2: sparse tables - devices/selector tables
print()
print('=== Vendor selector / devices tables ===')
for i, item in enumerate(d['items']):
    if item.get('type') != 12:
        continue
    name = item.get('name', '')
    for j, si in enumerate(item.get('content', {}).get('items', [])):
        if si.get('type') != 3:
            continue
        sn = si.get('name', '')
        title = si.get('content', {}).get('title', '')
        if 'selector' in sn or 'devices' in sn:
            labels = si.get('content', {}).get('gridSettings', {}).get('labelSettings', [])
            cols = [l['columnId'] for l in labels]
            print(f'  [{name}] name={sn} title={title}')
            print(f'    cols={cols}')

# Check 3: CISO references
print()
print('=== CISO references ===')
raw = json.dumps(d)
for m in re.finditer('CISO', raw):
    start = max(0, m.start() - 50)
    end = min(len(raw), m.end() + 50)
    snippet = raw[start:end].replace('\\n', ' ')
    print(f'  ...{snippet}...')

# Check 4: Header text
print()
print('=== Header Text ===')
for i, item in enumerate(d['items']):
    if item.get('name') == 'Header Text':
        print(f'  Index {i}')

# Check 5: Parameters
print()
print('=== Parameters ===')
params = d['items'][0]['content']['parameters']
for p in params:
    print(f'  name={p["name"]} type={p["type"]}')
