@echo off
REM Downloads and runs fix-vmicrdv.ps1 from GitHub. Run as Administrator inside the VM.
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing 'https://raw.githubusercontent.com/johnB007/Defender_XDR/main/temp/fix-vmicrdv.ps1' -OutFile $env:TEMP\fix-vmicrdv.ps1; & $env:TEMP\fix-vmicrdv.ps1"
