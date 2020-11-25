Configuration ConfigureMS
{
    [CmdletBinding()]
    param (
            [string]
            $ComputerName = 'ServerMS1'
        )
        Import-DscResource -ModuleName PSDesiredStateConfiguration
        Import-DscResource -ModuleName NetworkingDSC, ComputerManagementDSC
        Import-DscResource -ModuleName ActiveDirectoryDSC

        Node $ComputerName
        {
            LocalConfigurationManager
            {
                ConfigurationModeFrequencyMins = 15
                ConfigurationMode = 'ApplyAndAutoCorrect'
                RefreshMode = 'Push'
                RebootNodeIfNeeded = $true
                AllowModuleOverwrite = $true                
            } # end LCM

            # Disable Dhcp. Server will get a static IP
            NetIPInterface DisableDhcpMS
            {
                InterfaceAlias = 'Ethernet'
                AddressFamily = 'IPv4'
                Dhcp = 'Disabled'
            }

            # Assign IP address to ServerMS1
            IPAddress NewIpv4AddressMS #default /24 Class C
            {
                InterfaceAlias = 'Ethernet'
                IPAddress = '192.168.0.110'
                AddressFamily = 'IPv4'
                KeepExistingAddress = $true   
            }

            # Assign Host VM's Internal SW as gateway
            DefaultGatewayAddress GatewayAddressMS
            {
                InterfaceAlias = 'Ethernet'
                AddressFamily = 'IPv4'
                Address = '192.168.0.250'
            }

            # assign DC's address as Primary DNS
            DnsServerAddress DNSAddressMS            
            {
                AddressFamily = 'IPv4'
                InterfaceAlias = 'Ethernet'
                Address = '192.168.0.100', '1.1.1.1'
                #Validate = $true
            }

        } # end Node
} # end Configuration

ConfigureMS -ComputerName ServerMS1

#########################################################################
# NOTES:
# 1. Create a folder $env:TEMP\DSC and save this file in there
# 2. Run this script from that folder. 
# 3. It will create another sub-folder "ConfigureMS" with two .MOF files
# 4. Later you will copy these files to the Server2016-MS VM
#########################################################################