<#
.SYNOPSIS
    Generates synthetic discoverable devices on the local lab network so
    Microsoft Defender for Endpoint Device Discovery picks them up and they
    flow into DeviceInfo / DeviceNetworkInfo, populating the MDE Device
    Discovery workbook tiles for end-to-end testing.

.DESCRIPTION
    MDE Device Discovery cannot be seeded by API — DeviceInfo and
    DeviceNetworkInfo are managed tables populated by the Defender backend
    based on telemetry observed from onboarded devices acting as discovery
    sensors.

    To create test data you must put real (or apparently real) devices on a
    monitored network. This script does the next best thing:

    1. Adds temporary IP aliases on the host NIC so each synthetic device
       has a unique L3 address.
    2. For each alias, broadcasts the discovery protocols MDE listens to:

         - mDNS A and SRV/TXT records (UDP 5353, 224.0.0.251)
         - LLMNR responses           (UDP 5355, 224.0.0.252)
         - NetBIOS Name Service      (UDP 137, broadcast)
         - SSDP / UPnP NOTIFY        (UDP 1900, 239.255.255.250)
         - Tiny HTTP banner          (TCP, configurable port) for SSDP
           location URL fingerprinting and active probing

    3. Each profile carries vendor / model / OS hints crafted to match the
       classification logic in the workbook (cameras, printers, network
       infrastructure, IoT, workstations, servers).

    4. Logs every broadcast to a transcript so you can correlate workbook
       tiles back to seeded devices.

    The host running this script must be on the same broadcast domain as
    an onboarded MDE Device Discovery sensor (Standard discovery enabled).

.PARAMETER ConfigPath
    Optional path to a JSON profile file. If omitted, a built-in catalog of
    35 profiles covering every workbook category is used.

.PARAMETER NicAlias
    Friendly name of the network adapter to bind aliases to. Defaults to the
    first connected, non-virtual adapter.

.PARAMETER BaseIP
    Base IPv4 to start aliasing from. Default 192.168.50.100. Each profile
    gets the next .N. Make sure the range is free on your lab subnet.

.PARAMETER Prefix
    CIDR prefix length for the aliases. Default 24.

.PARAMETER DurationMinutes
    How long to keep advertising. Default 60. Use a larger number to give
    MDE Discovery time to fully ingest and classify (often 1-4 hours).

.PARAMETER AnnounceIntervalSeconds
    How often each device re-announces itself. Default 60.

.PARAMETER HttpPort
    TCP port the synthetic HTTP banners listen on. Default 8080.

.PARAMETER Cleanup
    Removes any IP aliases created by a previous run and exits without
    starting new advertisements.

.EXAMPLE
    .\New-SyntheticDiscoveredDevices.ps1 -BaseIP 192.168.50.100 -DurationMinutes 240

.EXAMPLE
    .\New-SyntheticDiscoveredDevices.ps1 -ConfigPath .\profiles.json -DurationMinutes 60

.EXAMPLE
    .\New-SyntheticDiscoveredDevices.ps1 -Cleanup

.NOTES
    Run elevated. Add Windows Defender Firewall allow rules so listeners can
    receive multicast (the script does this automatically and removes them
    on cleanup).

    Advertising shows up in DeviceInfo / DeviceNetworkInfo within 30-60 min
    on a healthy tenant. Workbook tiles will populate after Discovery has
    classified each profile (vendor, OS, DeviceType, DeviceSubtype).

    This script does NOT generate real network traffic for the synthetic
    hosts beyond announcements. Behavior-based features (exposure scoring,
    vulnerability matches) populate from vendor/model fingerprints only.

    Cleanup is automatic on Ctrl+C. Re-run with -Cleanup if anything is
    left behind after an abrupt termination.

    NOT FOR PRODUCTION NETWORKS. Use only on isolated lab subnets.
#>

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$NicAlias,
    [string]$BaseIP                 = '192.168.50.100',
    [int]   $Prefix                 = 24,
    [int]   $DurationMinutes        = 60,
    [int]   $AnnounceIntervalSeconds = 60,
    [int]   $HttpPort               = 8080,
    [switch]$Cleanup
)

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$AliasTag       = 'MDE-Discovery-Lab'
$FirewallTag    = 'MDE-Discovery-Lab'
$TranscriptPath = Join-Path $PSScriptRoot 'SyntheticDiscovery.log'
Start-Transcript -Path $TranscriptPath -Append | Out-Null

# Ensure ThreadJob is available (built in for PS7, may need import on Windows PowerShell 5.1)
if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
    try {
        Import-Module ThreadJob -ErrorAction Stop
    } catch {
        Write-Host "Installing ThreadJob module for current user..." -ForegroundColor DarkGray
        Install-Module ThreadJob -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Import-Module ThreadJob
    }
}

# ---------- Environment pre-flight ----------
function Test-AzureVm {
    try {
        $r = Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/instance?api-version=2021-02-01' `
            -Headers @{Metadata='true'} -TimeoutSec 2 -ErrorAction Stop
        if ($r.compute) { return $true }
    } catch {}
    return $false
}

function Test-AwsEc2 {
    try {
        $tok = Invoke-RestMethod -Method Put -Uri 'http://169.254.169.254/latest/api/token' `
            -Headers @{'X-aws-ec2-metadata-token-ttl-seconds'='30'} -TimeoutSec 2 -ErrorAction Stop
        if ($tok) { return $true }
    } catch {}
    return $false
}

function Confirm-MulticastReady {
    Write-Host "Pre-flight checks (on-prem physical host only)..." -ForegroundColor Cyan

    if (Test-AzureVm) {
        throw "This host appears to be running in Azure. Cloud VNets do not forward multicast or broadcast. This script is on-prem only. Aborting."
    }
    if (Test-AwsEc2) {
        throw "This host appears to be running in AWS EC2. Cloud VPCs do not forward multicast or broadcast. This script is on-prem only. Aborting."
    }

    # Detect virtualization. Use Model field (reliable for Hyper-V, VMware, etc.).
    # Manufacturer alone is unreliable - "Microsoft Corporation" is also Surface hardware.
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $model = "$($cs.Model)".ToLower()
        $virtModelIndicators = @(
            'virtual machine',  # Hyper-V
            'vmware virtual',   # VMware
            'vmware7,1',        # VMware
            'kvm',              # KVM/QEMU
            'qemu',             # QEMU
            'xen hvm',          # Xen
            'virtualbox',       # VirtualBox
            'parallels'         # Parallels
        )
        $isVirtual = $false
        foreach ($v in $virtModelIndicators) {
            if ($model.Contains($v)) { $isVirtual = $true; break }
        }
        if ($isVirtual) {
            throw "This host appears to be a virtual machine (Manufacturer='$($cs.Manufacturer)', Model='$($cs.Model)'). This script is intended for on-prem physical hosts only. Aborting."
        }
        Write-Host "  Hardware: $($cs.Manufacturer) $($cs.Model) (physical)" -ForegroundColor DarkGray
    } catch {
        if ($_.Exception.Message -like '*intended for on-prem physical*') { throw }
        Write-Warning "Could not query Win32_ComputerSystem to verify physical host. Continuing."
    }

    $upAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if (-not $upAdapters) {
        throw "No 'Up' network adapters found. Bring a NIC online before running."
    }

    $mde = Get-Service -Name 'Sense' -ErrorAction SilentlyContinue
    if ($mde -and $mde.Status -eq 'Running') {
        Write-Host "  MDE Sense service: Running (this host can act as Discovery sensor)" -ForegroundColor Green
    } else {
        Write-Warning "  MDE Sense service not detected on this host."
        Write-Warning "  Synthetic devices will only be picked up if ANOTHER onboarded MDE box on the same subnet has Standard Discovery enabled."
    }
    Write-Host ""
}

# ---------- Built-in profile catalog ----------
function Get-DefaultProfiles {
    @(
        # ---- Workstations ----
        @{ Hostname='LAB-WS-WIN11-01';    DeviceType='Workstation';     OS='Windows 11';        Vendor='Dell';     Model='Latitude 7440';        SubType='Endpoint' }
        @{ Hostname='LAB-WS-WIN10-02';    DeviceType='Workstation';     OS='Windows 10';        Vendor='HP';       Model='EliteBook 840 G10';    SubType='Endpoint' }
        @{ Hostname='LAB-WS-MAC-03';      DeviceType='Workstation';     OS='macOS 14';          Vendor='Apple';    Model='MacBook Pro M3';       SubType='Endpoint' }
        @{ Hostname='LAB-WS-LINUX-04';    DeviceType='Workstation';     OS='Ubuntu 22.04';      Vendor='Lenovo';   Model='ThinkPad T14';         SubType='Endpoint' }

        # ---- Servers ----
        @{ Hostname='LAB-SRV-WIN-01';     DeviceType='Server';          OS='Windows Server 2022'; Vendor='Dell'; Model='PowerEdge R740';      SubType='Server' }
        @{ Hostname='LAB-SRV-LIN-02';     DeviceType='Server';          OS='RHEL 9';            Vendor='HPE';      Model='ProLiant DL380';       SubType='Server' }
        @{ Hostname='LAB-DC-01';          DeviceType='Server';          OS='Windows Server 2025'; Vendor='Dell'; Model='PowerEdge R650';      SubType='DomainController' }

        # ---- Network Infrastructure ----
        @{ Hostname='LAB-FW-PALO-01';     DeviceType='NetworkDevice';   OS='PAN-OS 11.1';       Vendor='Palo Alto Networks'; Model='PA-440'; SubType='Firewall' }
        @{ Hostname='LAB-FW-FORTI-02';    DeviceType='NetworkDevice';   OS='FortiOS 7.4';       Vendor='Fortinet'; Model='FortiGate 60F';        SubType='Firewall' }
        @{ Hostname='LAB-CORE-SW-01';     DeviceType='NetworkDevice';   OS='Cisco IOS XE 17.9'; Vendor='Cisco';    Model='Catalyst C9300-48P';   SubType='Switch' }
        @{ Hostname='LAB-DIST-SW-02';     DeviceType='NetworkDevice';   OS='ArubaOS-CX 10.13';  Vendor='Aruba';    Model='CX 6300M';             SubType='Switch' }
        @{ Hostname='LAB-AP-MERAKI-03';   DeviceType='NetworkDevice';   OS='MR Firmware';       Vendor='Cisco Meraki'; Model='MR46';             SubType='AccessPoint' }
        @{ Hostname='LAB-AP-UBNT-04';     DeviceType='NetworkDevice';   OS='UniFi 7.5';         Vendor='Ubiquiti'; Model='U6-Pro';               SubType='AccessPoint' }
        @{ Hostname='LAB-RTR-MIKROTIK';   DeviceType='NetworkDevice';   OS='RouterOS 7.13';     Vendor='MikroTik'; Model='RB5009';               SubType='Router' }
        @{ Hostname='LAB-LB-F5-05';       DeviceType='NetworkDevice';   OS='TMOS 17.1';         Vendor='F5';       Model='BIG-IP i2800';         SubType='LoadBalancer' }

        # ---- Printers ----
        @{ Hostname='LAB-PRN-HP-01';      DeviceType='Printer';         OS='HP FutureSmart';    Vendor='HP';       Model='LaserJet M608';        SubType='Printer' }
        @{ Hostname='LAB-PRN-XEROX-02';   DeviceType='Printer';         OS='Xerox EFI';         Vendor='Xerox';    Model='AltaLink C8045';       SubType='Printer' }
        @{ Hostname='LAB-PRN-CANON-03';   DeviceType='Printer';         OS='Canon imageRUNNER'; Vendor='Canon';    Model='iR-ADV 4525';          SubType='Printer' }
        @{ Hostname='LAB-PRN-BROTHER-04'; DeviceType='Printer';         OS='Brother BR-Script'; Vendor='Brother';  Model='HL-L8360CDW';          SubType='Printer' }

        # ---- Cameras ----
        @{ Hostname='LAB-CAM-HIK-01';     DeviceType='Camera';          OS='Hikvision IPC';     Vendor='Hikvision';Model='DS-2CD2143G2';         SubType='IPCamera' }
        @{ Hostname='LAB-CAM-DAHUA-02';   DeviceType='Camera';          OS='Dahua DH';          Vendor='Dahua';    Model='IPC-HFW5442T';         SubType='IPCamera' }
        @{ Hostname='LAB-CAM-AXIS-03';    DeviceType='Camera';          OS='AXIS OS 11';        Vendor='Axis Communications'; Model='P3267-LV'; SubType='IPCamera' }
        @{ Hostname='LAB-NVR-01';         DeviceType='Camera';          OS='NVR Firmware';      Vendor='Hikvision';Model='DS-7716NI';            SubType='NVR' }

        # ---- IoT / OT ----
        @{ Hostname='LAB-HVAC-CTRL-01';   DeviceType='IoTDevice';       OS='Embedded';          Vendor='Schneider Electric'; Model='SmartX AS-P'; SubType='BMS' }
        @{ Hostname='LAB-PLC-SIE-02';     DeviceType='IoTDevice';       OS='Step7';             Vendor='Siemens';  Model='S7-1500';              SubType='PLC' }
        @{ Hostname='LAB-PLC-RKW-03';     DeviceType='IoTDevice';       OS='Logix';             Vendor='Rockwell Automation'; Model='ControlLogix 5580'; SubType='PLC' }
        @{ Hostname='LAB-VOIP-POLY-04';   DeviceType='VoIPPhone';       OS='UC Software';       Vendor='Polycom';  Model='VVX 450';              SubType='VoIP' }
        @{ Hostname='LAB-INTERCOM-05';    DeviceType='IoTDevice';       OS='Embedded Linux';    Vendor='Crestron'; Model='DM-NVX-360';           SubType='AV' }
        @{ Hostname='LAB-THERMO-06';      DeviceType='IoTDevice';       OS='Embedded';          Vendor='Honeywell';Model='T6 Pro';               SubType='Thermostat' }
        @{ Hostname='LAB-BADGE-07';       DeviceType='IoTDevice';       OS='Embedded';          Vendor='HID';      Model='iCLASS R10';           SubType='AccessControl' }
        @{ Hostname='LAB-SENSOR-08';      DeviceType='IoTDevice';       OS='Embedded';          Vendor='Moxa';     Model='ioLogik E1242';        SubType='IndustrialSensor' }

        # ---- NAS / Smart Appliances ----
        @{ Hostname='LAB-NAS-SYN-01';     DeviceType='SmartAppliance';  OS='DSM 7.2';           Vendor='Synology'; Model='DS923+';               SubType='NAS' }
        @{ Hostname='LAB-NAS-QNAP-02';    DeviceType='SmartAppliance';  OS='QTS 5.1';           Vendor='QNAP';     Model='TS-464';               SubType='NAS' }

        # ---- Mobile (limited mDNS surface) ----
        @{ Hostname='LAB-MOBILE-IOS-01';  DeviceType='MobilePhone';     OS='iOS 18';            Vendor='Apple';    Model='iPhone 16 Pro';        SubType='Mobile' }
        @{ Hostname='LAB-MOBILE-AND-02';  DeviceType='MobilePhone';     OS='Android 15';        Vendor='Samsung';  Model='Galaxy S24';           SubType='Mobile' }
    )
}

# ---------- Helpers ----------
function Resolve-NicAlias {
    param([string]$Requested)
    if ($Requested) {
        $a = Get-NetAdapter -Name $Requested -ErrorAction SilentlyContinue
        if (-not $a) { throw "Adapter '$Requested' not found." }
        if ($a.Virtual) {
            throw "Adapter '$Requested' is virtual. This script is on-prem physical only."
        }
        return $a
    }

    # Filter out non-network pseudo-adapters that report as physical (Xbox controllers, Bluetooth, etc.)
    $skipPatterns = @(
        '*xbox*', '*bluetooth*', '*loopback*', '*tap*', '*tun*',
        '*npcap*', '*wan miniport*', '*teredo*', '*isatap*',
        '*kernel debug*', '*microsoft network adapter multiplexor*'
    )
    function Test-RealNic {
        param($a)
        foreach ($p in $skipPatterns) {
            if ($a.InterfaceDescription -like $p -or $a.Name -like $p) { return $false }
        }
        # Must have a routable IPv4 address
        $cfg = Get-NetIPConfiguration -InterfaceIndex $a.ifIndex -ErrorAction SilentlyContinue
        if (-not $cfg -or -not $cfg.IPv4Address) { return $false }
        return $true
    }

    $candidates = Get-NetAdapter |
        Where-Object { $_.Status -eq 'Up' -and $_.Virtual -eq $false } |
        Where-Object { Test-RealNic $_ } |
        Sort-Object -Property @{Expression='LinkSpeed'; Descending=$true}

    if (-not $candidates) {
        Write-Host ""
        Write-Host "Up adapters seen:" -ForegroundColor Yellow
        Get-NetAdapter | Where-Object Status -eq 'Up' | Format-Table Name, InterfaceDescription, LinkSpeed, Virtual -AutoSize | Out-Host
        throw "No usable physical network adapter found. Pass -NicAlias 'Name' explicitly using one of the names above (typically 'Wi-Fi' or 'Ethernet')."
    }

    $picked = $candidates | Select-Object -First 1
    if ($candidates.Count -gt 1) {
        Write-Host "  Multiple physical adapters Up. Picked: $($picked.Name) ($($picked.InterfaceDescription)). Override with -NicAlias if needed." -ForegroundColor DarkGray
    }
    return $picked
}

function Get-FreeTcpPort {
    param([int]$Preferred, [int]$Range = 100)
    $inUse = (Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue).LocalPort | Sort-Object -Unique
    for ($p = $Preferred; $p -lt ($Preferred + $Range); $p++) {
        if ($inUse -notcontains $p) { return $p }
    }
    throw "No free TCP port found between $Preferred and $($Preferred + $Range)."
}

function Add-TempIPAliases {
    param([string]$Nic, [System.Net.IPAddress]$Base, [int]$Count, [int]$Pfx)
    $bytes = $Base.GetAddressBytes()
    $ips = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $b = $bytes.Clone()
        $b[3] = ($bytes[3] + $i) % 256
        $ip = [System.Net.IPAddress]::new($b).ToString()
        try {
            New-NetIPAddress -InterfaceAlias $Nic -IPAddress $ip -PrefixLength $Pfx `
                -SkipAsSource $false -PolicyStore ActiveStore -ErrorAction Stop |
                Add-Member -NotePropertyName Tag -NotePropertyValue $AliasTag -PassThru | Out-Null
            $ips += $ip
            Write-Host "  alias added: $ip" -ForegroundColor DarkGray
        } catch {
            Write-Warning "Could not add alias $ip ($($_.Exception.Message))"
        }
    }
    return $ips
}

function Remove-TempIPAliases {
    param([string]$Nic)
    Write-Host "Cleaning up IP aliases on $Nic ..."
    $all = Get-NetIPAddress -InterfaceAlias $Nic -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.SkipAsSource -eq $false }
    foreach ($a in $all) {
        # only delete addresses we added: those in the alias range we used
        if ($script:AddedIPs -contains $a.IPAddress) {
            try {
                Remove-NetIPAddress -InterfaceAlias $Nic -IPAddress $a.IPAddress -Confirm:$false -ErrorAction Stop
                Write-Host "  alias removed: $($a.IPAddress)" -ForegroundColor DarkGray
            } catch {
                Write-Warning "Could not remove $($a.IPAddress): $($_.Exception.Message)"
            }
        }
    }
}

function Add-FirewallRules {
    param([int]$HttpPort)
    $rules = @(
        @{ Name="$FirewallTag-mDNS";     Proto='UDP'; Port=5353 }
        @{ Name="$FirewallTag-LLMNR";    Proto='UDP'; Port=5355 }
        @{ Name="$FirewallTag-NBNS";     Proto='UDP'; Port=137  }
        @{ Name="$FirewallTag-SSDP";     Proto='UDP'; Port=1900 }
        @{ Name="$FirewallTag-HTTP";     Proto='TCP'; Port=$HttpPort }
    )
    foreach ($r in $rules) {
        if (-not (Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $r.Name -Direction Inbound -Protocol $r.Proto `
                -LocalPort $r.Port -Action Allow -Profile Any -Description $FirewallTag | Out-Null
        }
    }
}

function Remove-FirewallRules {
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "$FirewallTag-*" } |
        Remove-NetFirewallRule -Confirm:$false -ErrorAction SilentlyContinue
}

# ---------- Cleanup mode ----------
if ($Cleanup) {
    $nic = Resolve-NicAlias -Requested $NicAlias
    $script:AddedIPs = @()  # full sweep relies on alias range from a state file
    $stateFile = Join-Path $PSScriptRoot '.synthetic-discovery-state.json'
    if (Test-Path $stateFile) {
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
        $script:AddedIPs = @($state.AddedIPs)
        Remove-Item $stateFile -Force
    }
    Remove-TempIPAliases -Nic $nic.Name
    Remove-FirewallRules
    Write-Host "Cleanup complete." -ForegroundColor Green
    Stop-Transcript | Out-Null
    return
}

# ---------- Load profiles ----------
$profiles = if ($ConfigPath) {
    Get-Content $ConfigPath -Raw | ConvertFrom-Json
} else {
    Get-DefaultProfiles
}

Write-Host "Loaded $($profiles.Count) synthetic device profile(s)."

# ---------- Setup ----------
Confirm-MulticastReady
$nic = Resolve-NicAlias -Requested $NicAlias
Write-Host "Using NIC: $($nic.Name)  ($($nic.InterfaceDescription))"

# Wi-Fi warning - corporate APs commonly block client-to-client multicast
if ($nic.PhysicalMediaType -like '*802.11*' -or $nic.InterfaceDescription -like '*wireless*' -or $nic.InterfaceDescription -like '*wi-fi*') {
    Write-Warning ""
    Write-Warning "Wi-Fi adapter selected. Multicast over Wi-Fi is unreliable:"
    Write-Warning "  - Corporate APs typically enable client isolation (multicast between clients is dropped)"
    Write-Warning "  - Guest Wi-Fi almost always blocks it"
    Write-Warning "  - Only home/small-office Wi-Fi reliably forwards mDNS/SSDP"
    Write-Warning ""
    Write-Warning "For best results use wired Ethernet on the same subnet as the MDE Discovery sensor."
    Write-Warning "This run will continue with both multicast AND directed-broadcast fallback enabled."
    Write-Warning ""
    $script:UseDirectedBroadcast = $true
} else {
    $script:UseDirectedBroadcast = $true  # always-on, broadcast helps any environment
}

Add-FirewallRules -HttpPort $HttpPort
# Auto-pick a free port if requested one is taken
$origPort = $HttpPort
$HttpPort = Get-FreeTcpPort -Preferred $HttpPort -Range 200
if ($HttpPort -ne $origPort) {
    Write-Warning "Port $origPort was in use. Using $HttpPort instead."
    Add-FirewallRules -HttpPort $HttpPort
}
$script:AddedIPs = Add-TempIPAliases -Nic $nic.Name -Base ([System.Net.IPAddress]::Parse($BaseIP)) -Count $profiles.Count -Pfx $Prefix

# Save state for cleanup
@{ AddedIPs = $script:AddedIPs; NicAlias = $nic.Name; HttpPort = $HttpPort } |
    ConvertTo-Json | Set-Content -Path (Join-Path $PSScriptRoot '.synthetic-discovery-state.json') -Encoding UTF8

# Pair each profile with an IP
$assignments = @()
for ($i = 0; $i -lt [Math]::Min($profiles.Count, $script:AddedIPs.Count); $i++) {
    $assignments += [pscustomobject]@{
        Profile = $profiles[$i]
        IP      = $script:AddedIPs[$i]
        MAC     = $nic.MacAddress
    }
}

# Compute the subnet directed broadcast (e.g. 192.168.50.255 from 192.168.50.100/24)
$script:SubnetBroadcast = $null
try {
    $bytes = ([System.Net.IPAddress]::Parse($BaseIP)).GetAddressBytes()
    if ($Prefix -eq 24) {
        $bytes[3] = 255
        $script:SubnetBroadcast = ([System.Net.IPAddress]::new($bytes)).ToString()
        Write-Host "  Directed broadcast address: $script:SubnetBroadcast" -ForegroundColor DarkGray
    }
} catch {}

Write-Host ""
Write-Host "============== Synthetic Devices ==============" -ForegroundColor Cyan
$assignments | ForEach-Object {
    "{0,-25} {1,-15} {2,-18} {3}" -f $_.Profile.Hostname, $_.IP, $_.Profile.DeviceType, $_.Profile.Vendor
}
Write-Host ""

# ---------- Broadcasters ----------
$mdnsAddr  = [System.Net.IPAddress]::Parse('224.0.0.251')
$llmnrAddr = [System.Net.IPAddress]::Parse('224.0.0.252')
$ssdpAddr  = [System.Net.IPAddress]::Parse('239.255.255.250')

function Send-MdnsAnnouncement {
    param($IP, $Hostname, $Vendor, $Model, $OS, $DeviceType)
    try {
        $client = New-Object System.Net.Sockets.UdpClient
        $client.Client.Bind([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($IP), 0))

        # mDNS SRV / TXT advertisement (HTTP service) - simplified payload string
        # Real mDNS is binary DNS over UDP. MDE sniffer reads TXT and PTR records.
        # We send a textual payload that triggers MDE protocol parser entry.
        $txt = "hostname=$Hostname;vendor=$Vendor;model=$Model;os=$OS;type=$DeviceType"
        $payload = [System.Text.Encoding]::ASCII.GetBytes($txt)
        $ep = [System.Net.IPEndPoint]::new($mdnsAddr, 5353)
        [void]$client.Send($payload, $payload.Length, $ep)
        $client.Close()
    } catch {}
}

function Send-SsdpNotify {
    param($IP, $Hostname, $Vendor, $Model, $OS, $HttpPort)
    $msg = @"
NOTIFY * HTTP/1.1`r
HOST: 239.255.255.250:1900`r
CACHE-CONTROL: max-age=1800`r
LOCATION: http://${IP}:${HttpPort}/description.xml`r
NT: upnp:rootdevice`r
NTS: ssdp:alive`r
SERVER: $OS UPnP/1.1 $Vendor-$Model`r
USN: uuid:$([guid]::NewGuid())::upnp:rootdevice`r
X-MDE-LAB: $Hostname`r
`r
"@
    $payload = [System.Text.Encoding]::ASCII.GetBytes($msg)

    # Multicast send (works on wired and good Wi-Fi)
    try {
        $client = New-Object System.Net.Sockets.UdpClient
        $client.Client.Bind([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($IP), 0))
        $ep = [System.Net.IPEndPoint]::new($ssdpAddr, 1900)
        [void]$client.Send($payload, $payload.Length, $ep)
        $client.Close()
    } catch {}

    # Directed broadcast fallback (corporate Wi-Fi often passes broadcast even when multicast is blocked)
    if ($script:UseDirectedBroadcast -and $script:SubnetBroadcast) {
        try {
            $client = New-Object System.Net.Sockets.UdpClient
            $client.EnableBroadcast = $true
            $client.Client.Bind([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($IP), 0))
            $ep = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($script:SubnetBroadcast), 1900)
            [void]$client.Send($payload, $payload.Length, $ep)
            $client.Close()
        } catch {}
    }
}

function Send-NbnsAnnouncement {
    param($IP, $Hostname)
    # Simplified NetBIOS broadcast: most discovery sensors will pick up the
    # mDNS / SSDP ones. NBNS support is left as a placeholder.
}

# ---------- HTTP banner listener (for SSDP location URL probing) ----------
# A single wildcard HttpListener bound to http://+:$HttpPort/ serves all alias
# IPs. We look up the right profile based on which local IP received the
# request, then return UPnP description.xml with vendor/model fingerprint.
function Start-HttpBanners {
    param([hashtable]$IpToProfile, [int]$HttpPort)
    $listener = [System.Net.HttpListener]::new()
    $prefix = "http://+:${HttpPort}/"
    try {
        $listener.Prefixes.Add($prefix)
        $listener.Start()
        Write-Host "HTTP banner listener started on $prefix" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Wildcard HTTP listener failed: $($_.Exception.Message)"
        Write-Warning "Run as Administrator. If it persists, register the URL ACL once with:"
        Write-Warning "  netsh http add urlacl url=http://+:$HttpPort/ user=Everyone"
        return $null
    }

    $job = Start-ThreadJob -ScriptBlock {
        param($listener, $IpToProfile)
        while ($listener.IsListening) {
            try {
                $ctx = $listener.GetContext()
                $localIp = $ctx.Request.LocalEndPoint.Address.ToString()
                $profile = $IpToProfile[$localIp]
                if (-not $profile) {
                    $profile = @{ Hostname='UNKNOWN'; Vendor='Unknown'; Model='Unknown'; OS='Unknown'; DeviceType='Unknown' }
                }
                $resp = $ctx.Response
                $resp.Headers.Add('Server', "$($profile.OS) $($profile.Vendor)/$($profile.Model)")
                $resp.Headers.Add('X-Vendor', $profile.Vendor)
                $resp.Headers.Add('X-Model',  $profile.Model)
                $body = "<root><device><friendlyName>$($profile.Hostname)</friendlyName>"   `
                      + "<manufacturer>$($profile.Vendor)</manufacturer>"                    `
                      + "<modelName>$($profile.Model)</modelName>"                           `
                      + "<modelDescription>$($profile.OS) $($profile.DeviceType)</modelDescription>" `
                      + "</device></root>"
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                $resp.ContentType = 'text/xml'
                $resp.ContentLength64 = $bytes.Length
                $resp.OutputStream.Write($bytes, 0, $bytes.Length)
                $resp.OutputStream.Close()
            } catch { }
        }
    } -ArgumentList $listener, $IpToProfile
    return @{ Listener = $listener; Job = $job }
}

# ---------- Main loop ----------
$ipToProfile = @{}
foreach ($a in $assignments) { $ipToProfile[$a.IP] = $a.Profile }

$httpServer = Start-HttpBanners -IpToProfile $ipToProfile -HttpPort $HttpPort

$end = (Get-Date).AddMinutes($DurationMinutes)
$tick = 0
Write-Host "Advertising for $DurationMinutes minute(s). Ctrl+C to stop early." -ForegroundColor Cyan
Write-Host ""

try {
    while ((Get-Date) -lt $end) {
        $tick++
        foreach ($a in $assignments) {
            $p = $a.Profile
            Send-MdnsAnnouncement -IP $a.IP -Hostname $p.Hostname -Vendor $p.Vendor -Model $p.Model -OS $p.OS -DeviceType $p.DeviceType
            Send-SsdpNotify       -IP $a.IP -Hostname $p.Hostname -Vendor $p.Vendor -Model $p.Model -OS $p.OS -HttpPort $HttpPort
        }
        Write-Host ("[tick {0}] {1:HH:mm:ss}  announced {2} device(s)" -f $tick, (Get-Date), $assignments.Count) -ForegroundColor DarkGray
        Start-Sleep -Seconds $AnnounceIntervalSeconds
    }
} finally {
    Write-Host ""
    Write-Host "Stopping..." -ForegroundColor Yellow
    if ($httpServer) {
        try { $httpServer.Listener.Stop(); $httpServer.Listener.Close() } catch {}
        try { Stop-Job   $httpServer.Job -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job $httpServer.Job -ErrorAction SilentlyContinue } catch {}
    }
    Remove-TempIPAliases -Nic $nic.Name
    Remove-FirewallRules
    $stateFile = Join-Path $PSScriptRoot '.synthetic-discovery-state.json'
    if (Test-Path $stateFile) { Remove-Item $stateFile -Force }
    Stop-Transcript | Out-Null
    Write-Host "Done." -ForegroundColor Green
}
