@echo off
REM Run this inside the Hyper-V VM as Administrator.
REM Enables RDP + Hyper-V Enhanced Session, then reboots.
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=yes
sc config vmicrdv start= auto
sc start vmicrdv
shutdown /r /t 0
