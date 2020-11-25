Configuration ConfigureClient
{
    [CmdletBinding()]
    param (
            [string]
            $ComputerName = 'Client1'
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
            NetIPInterface DisableDhcpClient
            {
                InterfaceAlias = 'Ethernet'
                AddressFamily = 'IPv4'
                Dhcp = 'Disabled'
            }

            # Assign IP address to Client1
            IPAddress NewIpv4AddressClient #default /24 Class C
            {
                InterfaceAlias = 'Ethernet'
                IPAddress = '192.168.0.120'
                AddressFamily = 'IPv4'
                KeepExistingAddress = $true   
            }

            # Assign Host VM's Internal SW as gateway
            DefaultGatewayAddress GatewayAddressClient
            {
                InterfaceAlias = 'Ethernet'
                AddressFamily = 'IPv4'
                Address = '192.168.0.250'
            }

            # assign DC's address as Primary DNS
            DnsServerAddress DNSAddressClient
            {
                AddressFamily = 'IPv4'
                InterfaceAlias = 'Ethernet'
                Address = '192.168.0.100', '1.1.1.1'                
            }

        } # end Node
} # end Configuration

ConfigureClient -ComputerName Client1

#########################################################################
# NOTES:
# 1. Create a folder $env:TEMP\DSC and save this file in there
# 2. Run this script from that folder. 
# 3. It will create another sub-folder "ConfigureClient" with two .MOF files
# 4. Later you will copy these files to the Win10-Client VM
#########################################################################