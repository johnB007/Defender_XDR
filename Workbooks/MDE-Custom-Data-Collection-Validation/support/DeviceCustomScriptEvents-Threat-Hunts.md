# DeviceCustomScriptEvents threat hunting queries

Eleven KQL hunts against `DeviceCustomScriptEvents` (the AmsiScriptContent custom
data collection table), built for the signature and DFIR team to triage what
threat actors hide inside script content: embedded IOCs and common PowerShell
obfuscation TTPs. Every query below was validated live against SOC-Central
with real 7 day data before being saved.

## 1. Embedded IPv4 address

```kql
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
base LOLBin filter alone matched 51933 rows in the same window, confirming
the table and fields resolve correctly. The full three part combo returned
0 rows, a genuine true negative for this tenant since the collected
command lines are short wrapper invocations that call a .ps1 file by path
rather than embedding the download and execute logic inline.

## 13. ClickFix LOLBin download, execute, and evasion combo (ScriptContent)

Source: adapted from Microsoft Threat Intelligence, [Think before you Click(Fix): Analyzing the ClickFix social engineering technique](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), Microsoft Security Blog, August 21 2025.

```kql
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

Source: adapted from Microsoft Threat Intelligence, [Think before you Click(Fix): Analyzing the ClickFix social engineering technique](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), Microsoft Security Blog, August 21 2025.

```kql
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('I am not a robot', 'Verification ID', 'verification ID', 'CAPTCHA', 'Captcha', 'Human verification', 'human verification', 'Cloud identificator', 'Press Win', 'Windows+R', 'Win+R')
    and ScriptContent has_any ('iex', 'IEX', 'Invoke-Expression', 'powershell', 'mshta', 'curl', 'DownloadString', 'FromBase64String')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, ScriptContent, RuleName
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
text. Validation note: the phrase and combo matching logic was confirmed
against a known matching literal string, and returned 0 rows in the live
window, a clean result consistent with no ClickFix activity in this
tenant.


Source: adapted from Microsoft Threat Intelligence, [Think before you Click(Fix): Analyzing the ClickFix social engineering technique](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), Microsoft Security Blog, August 21 2025.

```kql
DeviceCustomScriptEvents
| where Timestamp > ago(7d)
| where isnotempty(ScriptContent)
| where ScriptContent has_any ('I am not a robot', 'Verification ID', 'verification ID', 'CAPTCHA', 'Captcha', 'Human verification', 'human verification', 'Cloud identificator', 'Press Win', 'Windows+R', 'Win+R')
    and ScriptContent has_any ('iex', 'IEX', 'Invoke-Expression', 'powershell', 'mshta', 'curl', 'DownloadString', 'FromBase64String')
| project Timestamp, DeviceName, InitiatingProcessFileName, InitiatingProcessAccountName, ScriptContent, RuleName
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
text. Validation note: the phrase and combo matching logic was confirmed
against a known matching literal string, and returned 0 rows in the live
window, a clean result consistent with no ClickFix activity in this
tenant.
