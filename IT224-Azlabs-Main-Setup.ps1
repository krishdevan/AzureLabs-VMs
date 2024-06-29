#######################################################################
# https://github.com/edgoad/ITVMs/blob/master/IT224/01-MainSetup.ps1
# First script for building Hyper-V environment for IT 224
# Installs Hyper-V and preps for OS installs
# Srv 2022 and Win11 Enterprise
#
#######################################################################

# Create a temp folder you will delete later
# Change directory to for working
$myTemp = "C:\MyTemp"
if (-not (Test-Path $myTemp) ) {
    New-Item -Path $myTemp -ItemType Directory
}

# Hide the folder
Get-Item $myTemp | foreach-object {$_.Attributes = $_.Attributes -bor "Hidden"}

# Download and import CommonFunctions module
$url = "https://raw.githubusercontent.com/krishdevan/AzureLabs-VMs/main/CommonFunctions.psm1"
$output = $(Join-Path $myTemp '/CommonFunctions.psm1')
if (-not(Test-Path -Path $output -PathType Leaf)) {
    (new-object System.Net.WebClient).DownloadFile($url, $output)
}
Import-Module $output
#Remove-Item $output

# Disable Server Manager at startup
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose

# Setup first interface
if ( $(Get-NetAdapter | Measure-Object).Count -eq 1 ){
    Write-Host "Setting Public adapter name"
    Get-NetAdapter | Rename-NetAdapter -NewName MyPublic
}
else{
    Write-Host "Cannot set Public interface name. Confirm interfaces manually."
}
# Install Hyper-V
Install-HypervAndTools

# Create virtual swith
if ( ! (Get-VMSwitch | Where-Object Name -eq 'NatInternalSw')){
    Write-Host "Creating Internal vswitch"
    New-VMSwitch -SwitchType Internal -Name NatInternalSw
} else { Write-Host "Internal vSwitch already created" }

# Setup second interface
if ( ! (Get-NetAdapter | Where-Object Name -EQ 'NatInternalAdapter')){
    Write-Host "Configuring Internal adapter"
    Get-NetAdapter | where Name -NE 'MyPublic' | Rename-NetAdapter -NewName NatInternalAdapter
    New-NetIPAddress -InterfaceAlias 'NatInternalAdapter' -IPAddress 192.168.0.250 -PrefixLength 24
} else { Write-Host "Internal adapter already exists. Confirm interfaces manually" }

# Configure routing / NAT
New-NetNat -Name external_routing -InternalIPInterfaceAddressPrefix 192.168.0.0/24

#######################################################################
# Install some common tools
#######################################################################
# Install 7-Zip
#Install-7Zip

# Configure logout after 10 minutes
Set-Autologout

#######################################################################
# Start setting up Hyper-V
#######################################################################
Set-HypervDefaults

<# 
Download Windows Server 2016 ISO
New-Item -ItemType Directory -Path c:\VMs -Force
$url = "https://software-download.microsoft.com/download/pr/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
$output = "c:\VMs\W2k2016.ISO"
Get-WebFile -DownloadUrl $url -TargetFilePath $output

#Download Windows 10 ISO
New-Item -ItemType Directory -Path c:\VMs -Force
$url = "https://software-download.microsoft.com/download/pr/18363.418.191007-0143.19h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
$output = "c:\VMs\Win10.ISO"
Get-WebFile -DownloadUrl $url -TargetFilePath $output

#>

# Download Server 2022
#######################################################################
# Have to go to MSFT Eval center to download the ISOs freshly
# These links change or ISO downloaded from these links don't work
#######################################################################
# $server2022url = "https://go.microsoft.com/fwlink/p/?linkid=2195333"
$ServerIsoPath = "C:\ISOs\W2K22.iso"
Get-WebFile -DownloadUrl $server2022url -TargetFilePath $ServerIsoPath

# Download Windows 11 Enterprise ISO
# Ensure TPM is enabled for the VM
# Ensure VM is at least 4GB RAM
# Ensure Number of processors is minimum 2
$win11enturl = "https://go.microsoft.com/fwlink/p/?LinkID=2206317&clcid=0x409&culture=en-us&country=US"
$win11IsoPath = "c:\ISOs\Win11-Ent.ISO"
Get-WebFile -DownloadUrl $win11enturl -TargetFilePath $win11IsoPath

# Setup Hyper-V default file locations
$baseVMPath = "C:\VMs"
$vhdPath = "C:\VMs\Virtual Hard Disks"

#########################################################################################
# Create DC1 hashtable for DC1 VM
##################################
$dc1VM                 = @{
	Name               = "DC1"
	MemoryStartupBytes = 2GB 		# no quotes
	BootDevice         = "VHD"
	NewVHDPath         = "$vhdPath\DC1.vhdx"
	NewVHDSizeBytes    = 50GB		# no quotes
	SwitchName         = "NatInternalSw"
	Generation         = 2
	Path               = $baseVMPath # C:\VMs\<VMName>
}
#################
# Create DC1 VM
#################
New-VM @dc1VM
Add-VMDvdDrive -VMName DC1 -Path $ServerIsoPath
#########################################################################################
# Create DM1 hashtable for DM1 VM
##################################
$dm1VM                 = @{
	Name               = "DM1"
	MemoryStartupBytes = 2GB		# no quotes
	BootDevice         = "VHD"
	NewVHDPath         = "$vhdPath\DM1.vhdx"
	NewVHDSizeBytes    = 40GB		# no quotes
	SwitchName         = "NatInternalSw"
	Generation         = 2
	Path               = $baseVMPath # C:\VMs\<VMName>
}
#################
# Create DM1 VM
#################
New-VM @dm1VM
Add-VMDvdDrive -VMName DM1 -Path $ServerIsoPath
#########################################################################################
# Create SWS hashtable for SWS VM
##################################
$swsVM                 = @{
	Name               = "SWS"
	MemoryStartupBytes = 4GB		# no quotes
	BootDevice         = "VHD"
	NewVHDPath         = "$vhdPath\SWS.vhdx"
	NewVHDSizeBytes    = 25GB		# no quotes
	SwitchName         = "NatInternalSw"
	Generation         = 2
	Path               = $baseVMPath # C:\VMs\<VMName>
}
#################
# Create SWS VM
#################
New-VM @swsVM
Add-VMDvdDrive -VMName SWS -Path $win11IsoPath
############################
# SET vCPU count for Win 11
# 
Get-VM -Name "SWS" | Set-VM -ProcessorCount 2 -DynamicMemory
#########################
# Enable VTPM for Win 11
#
Set-VMKeyProtector -VMName "SWS" -NewLocalKeyProtector
Enable-VMTPM -VMName SWS
#########################################################################################
# Set boot order of VMs
Get-VM | ForEach-Object {
    $vmDvd = Get-VMDvdDrive $_
    $vmHd = Get-VMHardDiskDrive $_
    $vmNic = Get-VMNetworkAdapter $_
    Set-VMFirmware $_ -BootOrder $vmHd, $vmDvd, $vmNic
}

# Set all VMs to NOT autostart
Get-VM | Set-VM -AutomaticStartAction Nothing

# Set all VMs to shutdown at logoff
Get-VM | Set-VM -AutomaticStopAction Shutdown

# Set VMs to 2 processors for optimization
Get-VM | Set-VMProcessor -Count 2

# setup bginfo
# Set-DesktopDefaults

# Download Network Diagram
Write-Host "Downloading Network Diagram"
$url = "https://raw.githubusercontent.com/krishdevan/AzureLabs-VMs/main/IT224_NetworkDiagram.png"
$output = "c:\Users\Public\Desktop\Network Diagram.png"
Get-WebFile -DownloadUrl $url -TargetFilePath $output

########################################################################
## INSTALL THE OS NOW INDIVIDUALLY
########################################################################

#########################################################
# Capture snapshot of VMs AFTER OS in installed 
#########################################################
Get-VM | Stop-VM 
Get-VM | Checkpoint-VM -SnapshotName "Initial OS Install" 

#########################################################
# Setup Rename of host
#########################################################
$command = 'powershell -Command "& { rename-computer -newname $( $( -join ((65..90) + (97..122) | Get-Random -Count 12 | %{[char]$_})) ).SubString(0,12) }"'
New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name "Rename" -Value $Command -PropertyType ExpandString