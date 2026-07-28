# Demo: Code Spell Checker (streetsidesoftware.code-spell-checker)

This file has intentional misspellings. Open it and you should see:

1. Squiggly underlines under each misspelled word.
2. The Problems panel (Ctrl+Shift+M) lists every typo with the rule "cspell".
3. Hovering a flagged word offers Quick Fix (Ctrl+.) with suggested replacements
   and an option to "Add to user dictionary".

## Sample paragraph with errors

The Defenderr XDR architct deteccted seven incidnts overnght. The hunters
quickkly trigaed each alrt, escallated two to the SOC manger, and confimred that
no senstive data was exfiltrated. The detection rools have been updatted, the
workbooks repulshed, and the affected acconts disabbled until the investigaton
completes.

## Try this

- Click any underlined word.
- Press Ctrl+. (Quick Fix). Pick the correct spelling.
- For SOC jargon ("MDE", "AAD", "ASR") use "Add to user dictionary" so it
  stops flagging them everywhere.

## Code blocks are checked too

```powershell
# This commnent has a typo. So does the variable name.
$indcidentCount = 5
Write-Host "Procesing $indcidentCount alrts"
```

## What it does NOT flag

- Code identifiers like `DeviceProcessEvents` (camelCase split into known words).
- File paths and URLs.
- Things in your user dictionary.
