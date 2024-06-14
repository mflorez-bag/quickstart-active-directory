configuration PrepareADBDC
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DNSServer,

        [Int]$RetryCount=25,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xStorage, xNetworking

    $Interface = Get-NetAdapter | Where-Object { 
        $_.Status -eq "Up" -and 
        $_.Name -like "Ethernet*" -and 
        $_.InterfaceDescription -like "Microsoft*" 
    } | Select-Object -First 1
    
    # Check if a likely primary Ethernet adapter with the correct description was found
    if (-not $Interface) {
        throw "No suitable Ethernet adapter found."
    } else {
        Write-Verbose -Message "Suitable network adapter found: Name = $($Interface.Name), Description = $($Interface.InterfaceDescription)"
    }
    
    # Use the InterfaceAlias for further configurations or operations
    $InterfaceAlias = $Interface.Name

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        xWaitforDisk Disk1
        {
            DiskNumber = 1
            RetryIntervalSec = $RetryIntervalSec
            RetryCount = $RetryCount
        }

        xDisk ADDataDisk
        {
            DiskNumber = 1
            DriveLetter = "F"
            DependsOn = "[xWaitForDisk]Disk1"
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        WindowsFeature ADDSTools
        {
            Ensure = "Present"
            Name = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSTools"
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = $DNSServer
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
    }
}
