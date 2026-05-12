# MDE / Azure Arc On-Box Connectivity Verification (IL5 / USGovDoD)

**Scope:** Quick on-box checks to run on a Windows Server before (or right after) attempting Azure Arc onboarding and MDE.Windows extension install in Azure Government (IL5). These complement the scripted [Pre-Req Connectivity Check](MDE_ARC_Pre_Req.md). Run them when you need a fast manual sanity check or when you suspect a firewall break and inspect (TLS interception) issue.

> Run all commands from an **elevated PowerShell** prompt on the target server.

## 1. Validate core Azure Arc onboarding endpoints

Covers the wildcard namespaces `*.his.arc.azure.us` and `*.guestconfiguration.azure.us` plus the rest of the required Arc URL set, in one shot, using the agent's built in checker.

> **Verify the install path first.** The agent isn't always under `Program Files`. Confirm with:
>
> ```powershell
> sc.exe qc himds
> # BINARY_PATH_NAME shows the real install location.
> ```
>
> If your install path differs, change the `cd` target below.

```powershell
cd "C:\Program Files\AzureConnectedMachineAgent"
.\azcmagent.exe check --location usgovvirginia --cloud AzureUSGovernment
```

**Pass criteria:** every URL in the output table reports **Reachable: true**. Any `false` row is a firewall, proxy, or DNS gap that will block onboarding or extension installs.

## 2. Validate the Azure Storage (Gov) path

Covers `*.blob.core.usgovcloudapi.net`, which the **MDE.Windows** extension and other Arc extensions use to download their handler packages.

> **Use a real storage account name in your tenant.** Made up names fail at DNS resolution and never actually test the firewall rule. To grab one: in the Azure portal go to **Storage accounts**, then **\<any account\>**, then **Endpoints**, copy the **Blob service** hostname (example: `cs2275nd90.blob.core.usgovcloudapi.net`).

```powershell
Test-NetConnection <xxxxx>.blob.core.usgovcloudapi.net -Port 443
```

**Pass criteria:**

* `TcpTestSucceeded : True`
* `RemoteAddress` resolves to a routable IP (not `0.0.0.0` or empty).

A `TcpTestSucceeded : False` here is the most common reason for `MDE.Windows` extension failures with download or 403 errors in `gcm.log`.

## 3. Verify the firewall is **not** doing TLS break and inspect

If a 3rd party firewall (Palo Alto, Zscaler, Netskope, Forcepoint, etc.) is intercepting TLS, the cert presented to the server will be the **firewall's** cert, not Microsoft's, and Arc / MDE will fail with TLS chain errors even though TCP 443 succeeds.

This check inspects the certificate actually delivered to the host on port 443 to one of the Gov guest configuration storage endpoints:

```powershell
$target='oaasguestconfigusgvs1.blob.core.usgovcloudapi.net'
$tcp=[System.Net.Sockets.TcpClient]::new($target,443)
$ssl=[System.Net.Security.SslStream]::new($tcp.GetStream(),$false,{$true})
$ssl.AuthenticateAsClient($target)
$ssl.RemoteCertificate | Select-Object Subject, Issuer, NotBefore, NotAfter
```

**How to read the result:**

| `Issuer` value contains | Meaning |
|---|---|
| `Microsoft`, `Microsoft Azure`, `DigiCert` (Microsoft chained) | Good. Direct TLS to Microsoft, no interception. |
| `Palo Alto`, `Zscaler`, `Netskope`, your internal CA, or any non Microsoft issuer | Break and inspect is in place. The firewall is terminating TLS and re signing with its own CA. |

**If break and inspect is detected:** request a **TLS bypass / SSL decryption exclusion** from the network team for the Arc and MDE FQDNs (at minimum `*.his.arc.azure.us`, `*.guestconfiguration.azure.us`, `*.blob.core.usgovcloudapi.net`, `*.endpoint.security.microsoft.us`, `*.securitycenter.microsoft.us`). Microsoft does not support running Arc or MDE behind a TLS intercepting proxy.

**Cleanup (optional, same session):**

```powershell
$ssl.Dispose(); $tcp.Dispose()
```

### 3.1 Palo Alto: No-Decrypt rule for Arc and MDE traffic

Microsoft's stance is documented in [Configure your network environment to ensure connectivity with Defender for Endpoint service](https://learn.microsoft.com/defender-endpoint/configure-environment):

> "Proxies shouldn't require authentication for these destinations or perform inspection (HTTPS scanning / SSL inspection) that breaks the secure channel."

Palo Alto Networks documents the same constraint on **page 101** of the [Decryption Administration Guide (PDF)](https://docs.paloaltonetworks.com/content/dam/techdocs/en_US/pdf/network-security/decryption-administration.pdf):

> "Traffic that breaks decryption for technical reasons, such as using a pinned certificate, an incomplete certificate chain, unsupported ciphers, or mutual authentication (attempting to decrypt the traffic results in blocking the traffic). There are two constructs for sites that break decryption for technical reasons and therefore need to be excluded from decryption: the predefined SSL decryption exclusion list and the Local SSL Decryption Exclusion Cache. If a website whose applications and services break decryption technically are not in the predefined SSL decryption exclusion list or the local SSL decryption cache, the NGFW blocks them unless you add them to a **custom SSL decryption exclusion list**."

Arc agent <-> ARM, the guest configuration channel, and the MDE.Windows extension package downloads all use certificate pinning and / or strict TLS validation that Palo's outbound SSL Forward Proxy decryption will break. The fix is a **No-Decrypt** policy (custom SSL decryption exclusion) on the Palo Alto NGFW for the Microsoft destinations below.

**Custom SSL decryption exclusion list (URL Category / Custom URL list to attach to a No-Decrypt rule):**

```
*.blob.core.usgovcloudapi.net
*.guestconfiguration.azure.us
*.his.arc.azure.us
*.usgovcloudapi.net
```

Recommended additions for the same rule (cover MDE control plane and onboarding portal flows):

```
*.endpoint.security.microsoft.us
*.securitycenter.microsoft.us
unitedstates2.ss.wd.microsoft.us
unitedstates2.cp.wd.microsoft.us
config.ecs.dod.teams.microsoft.us
login.microsoftonline.us
```

**Where to configure on the Palo Alto NGFW:**

1. **Objects > Custom Objects > URL Category**: create a custom category (e.g. `Microsoft-Arc-MDE-NoDecrypt`) and add the FQDNs above.
2. **Policies > Decryption**: create a new rule above your existing SSL Forward Proxy decrypt rule.
   * Source: the Arc / MDE server zones or address groups.
   * Destination: any.
   * Service / URL Category: the custom category from step 1.
   * Action: **No Decrypt**.
   * Type: **SSL Forward Proxy**.
3. **Commit** the configuration.

**Verification in Palo Alto traffic logs (Monitor > Logs > Traffic):**

After committing the No-Decrypt rule, on the affected server **delete the failed Arc extension**, then re-trigger the install (Defender for Cloud will re-push, or run from the **Extensions** blade on the Arc machine resource).

In the Palo traffic log, filter on:

```
( url contains 'blob.core.usgovcloudapi.net' ) or
( url contains 'guestconfiguration.azure.us' ) or
( url contains 'his.arc.azure.us' )
```

You should see:

* **Action: allow**
* **Decrypted: no** (or the decrypt column blank)
* **Application: ssl** (not `incomplete` or `insufficient-data`)

If you instead see **deny**, **drop**, **reset-server**, or **reset-both**, the rule isn't matching (check ordering above the broad decrypt rule, source zone, and the URL category contents) or another security profile (URL Filtering, App-ID override, Threat) is still blocking the session. Further troubleshooting required before the extension will install.

### 3.2 If the extension still fails: collect handler logs

Pull the following from the Arc machine and send them over so we can correlate against the Palo Alto traffic logs:

```
C:\ProgramData\GuestConfig\extension_logs\Microsoft.Azure.AzureDefenderForServers.MDE.Windows\*\
```

Specifically:

* `CommandExecution.log`
* `CustomScriptHandler.log` (or any file with `Handler` in the name)
* `error.log`
* `output.log`

Quick collector to zip the latest version's logs:

```powershell
$root = "C:\ProgramData\GuestConfig\extension_logs\Microsoft.Azure.AzureDefenderForServers.MDE.Windows"
$latest = Get-ChildItem $root -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$dest = "$env:USERPROFILE\Desktop\MDE_Windows_Extension_Logs_$($env:COMPUTERNAME)_$(Get-Date -Format yyyyMMdd-HHmmss).zip"
Compress-Archive -Path "$($latest.FullName)\*" -DestinationPath $dest -Force
"Wrote $dest"
```

Also useful in the same ticket:

* `C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log`
* `C:\ProgramData\AzureConnectedMachineAgent\Log\gcm.log`
* The Palo Alto traffic-log export filtered as in 3.1 for the same time window.

## Quick reference: what each check proves

| # | Check | Proves |
|---|---|---|
| 1 | `azcmagent check --cloud AzureUSGovernment` | All Arc onboarding and extension control plane URLs reachable |
| 2 | `Test-NetConnection <real>.blob.core.usgovcloudapi.net 443` | Extension package download path open |
| 3 | `SslStream.AuthenticateAsClient` plus cert issuer inspection | No TLS break and inspect on the path |

If all three pass, the host is network ready for Arc onboarding and the MDE.Windows extension push from Defender for Cloud.
