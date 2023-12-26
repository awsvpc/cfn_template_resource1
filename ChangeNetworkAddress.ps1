Set-StrictMode -Version 2.0
<#
        .SYNOPSIS
        Script to change your MAC & IP Address instantly.

        .DESCRIPTION
        [Input] Change $NetworkAdapterName to the network adapter that you are using.
        [Output] MAC Address is randomly assigned from 00-00-00-00-00 to FF-FF-FF-FF-FF
        [Output] IP Address is randomly assigned from xxx.xxx.xxx.100/24 to xxx.xxx.xxx.250/24
        
        [Note] Run this script with administration rights.
        [Note] Only works for internet enabled network as it performs a nslookup to internetbeacon.msedge.net
        [Recommendation] Instead of running this script manually you can create a schtasks for it.
        
        .EXAMPLE
        Open cmd with administrator rights
        Type: powershell -ep bypass -f ChangeNetworkAddress.ps1

        .EXAMPLE
        Open cmd with administrator rights
        Type: schtasks /create /sc onlogon /tn "ChangeNetworkAddress" /tr "powershell -ep bypass -f ChangeNetworkAddress.ps1" /ru system

        .PARAMETER Name
        $NetworkAdapterName = "<Intel(R) Wi-Fi 6 AX201 160MHz>"
        
#>
$NetworkAdapterName = "Intel(R) Wi-Fi 6 AX201 160MHz"
$Cipher = @("0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F")
$NetworkAdapterAlias = (Get-NetAdapter -InterfaceDescription $NetworkAdapterName).Name
$NetworkInterfaces = (Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue).Name
$UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$UserPrincipal = New-Object System.Security.Principal.WindowsPrincipal($UserId)
if (!$UserPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)){ 
    Write-Output Write-Host "[ERROR] Not running in administrator mode."
    exit
}             
foreach ($NetworkInterface in $NetworkInterfaces)
{
  $Index = $NetworkInterface.Split("\")[-1]
  if ($Index -match "^[0-9]*$"){
    $NetworkRegistryPath = "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\$Index"
    if((Get-ItemProperty -Path $NetworkRegistryPath).DriverDesc -eq $NetworkAdapterName){
        break
    }
  }
  $Index = ""
}
if (!($Index -eq "")){
    $NewMacAddress = @()
    for ($i=0;$i -lt 6; $i++){
        $IntRandom1 = Get-Random -Minimum 0 -Maximum 16
        $IntRandom2 = Get-Random -Minimum 0 -Maximum 16
        $NewMacAddress+=$Cipher[$IntRandom1]+$Cipher[$IntRandom2]
    }
    $NewMacAddress = $NewMacAddress -join "-"
    Set-ItemProperty -Path $NetworkRegistryPath -Name "NetworkAddress" -Value $NewMacAddress -ErrorAction Stop
    Write-Host "[INFO] Success MAC Address = $NewMacAddress"
    
}else{
    Write-Host "[ERROR] Network Adapter cannot be found. IP & MAC Address not changed."
    exit
}
try{
    $IPv4Address = (Get-NetIPConfiguration -InterfaceAlias $NetworkAdapterAlias -Detailed -ErrorAction Stop).IPv4Address.IPAddress
    $IPv4DefaultGateway = (Get-NetIPConfiguration -InterfaceAlias $NetworkAdapterAlias -Detailed  -ErrorAction Stop).IPv4DefaultGateway.NextHop
}catch{
    Write-Host "[ERROR] Network Adapter cannot be found. IP Address not changed."
}

$Mask = "255.255.255.0"
$IPv4AddressArray = $IPv4Address.split(".")
$MinOctet = 100
$MaxOctet = 250
$Range = [int] $MaxOctet - [int] $MinOctet
$IpTracker = @{
    $IPv4AddressArray[-1] = $true
}

if(!(Test-NetConnection -ErrorAction SilentlyContinue).PingSucceeded){
    Write-Host "[ERROR] No internet connection. Unable to change IP."
    exit
}
for ($i=0;$i -lt $Range; $i++){
    $IntRandom = Get-Random -Minimum $MinOctet -Maximum $MaxOctet
    if ($IpTracker[$IntRandom] -eq $null){
        $IpTracker[$IntRandom] = $true
        $IPv4AddressArray[-1] = $IntRandom
        $IPv4Address = $IPv4AddressArray -join "."
        netsh interface ipv4 set address name="$NetworkAdapterAlias" static $IPv4Address $Mask $IPv4DefaultGateway
        Write-Host "[INFO] Setting $IPv4Address (5 secs)"
        Start-Sleep -s 5 
        if((Test-NetConnection -ErrorAction SilentlyContinue).PingSucceeded){
            Write-Host "[INFO] Success IP Address = $IPv4Address"
            break
        }else{
            Write-Host "[INFO] Unable to use Octet $IntRandom"
            continue
        }
    }  
}
