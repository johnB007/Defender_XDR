# temp — one-time lab VM bootstrap

Throwaway helpers for the `non-mde` Hyper-V lab VM. Delete this folder when the lab is set up.

## enable-rdp.cmd — run this inside the VM, one time

1. In the VM, open Edge.
2. Go to: `https://raw.githubusercontent.com/johnB007/Defender_XDR/main/temp/enable-rdp.cmd`
3. Save to Downloads.
4. Right-click → **Run as administrator**.
5. Write down the IPv4 address it prints at the end (looks like `192.168.x.x`).

## Then connect from the host

On the host, in any PowerShell window:

```
mstsc /v:<the-ipv4-from-step-5>
```

Sign in with the VM's local account. Full clipboard, resizable window. Done.
