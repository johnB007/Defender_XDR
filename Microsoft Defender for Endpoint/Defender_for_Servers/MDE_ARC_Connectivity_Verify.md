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

## Quick reference: what each check proves

| # | Check | Proves |
|---|---|---|
| 1 | `azcmagent check --cloud AzureUSGovernment` | All Arc onboarding and extension control plane URLs reachable |
| 2 | `Test-NetConnection <real>.blob.core.usgovcloudapi.net 443` | Extension package download path open |
| 3 | `SslStream.AuthenticateAsClient` plus cert issuer inspection | No TLS break and inspect on the path |

If all three pass, the host is network ready for Arc onboarding and the MDE.Windows extension push from Defender for Cloud.
