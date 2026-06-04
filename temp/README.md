Run inside the Hyper-V VM as Administrator. Five lines, last one reboots.

    reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
    netsh advfirewall firewall set rule group="remote desktop" new enable=yes
    sc config vmicrdv start= auto
    sc start vmicrdv
    shutdown /r /t 0

After it reboots, close vmconnect, reopen the VM from Hyper-V Manager, pick a resolution, connect. Clipboard works.
