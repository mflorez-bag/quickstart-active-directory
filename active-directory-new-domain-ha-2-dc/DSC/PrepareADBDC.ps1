configuration PrepareADBDC
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DNSServer,

        [Int]$RetryCount=16,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xStorage, xNetworking

    $Interface = Get-NetAdapter | Where-Object { $_.Name -Like "Ethernet*" } | Select-Object -Last 1
    if (-not $Interface) {
        throw "No Ethernet adapter found."
    } else {
        Write-Verbose -Message "Network adapter found: $($Interface.Name)"
    }
    $InterfaceAlias = "Ethernet" # $Interface.Name

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
