@echo off
REM Enable RDP, open firewall, add current user to Remote Desktop Users. Run as Administrator inside the VM.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'; try { Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $env:USERNAME -ErrorAction Stop } catch { Write-Host $_ }; Get-LocalGroupMember 'Remote Desktop Users'; ipconfig | Select-String 'IPv4'"
pause
