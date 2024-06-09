<#
    THIS MODULE CONTAINS FUNCTIONS RELATED TO PINGCASTLE V3.2.0.1

    Fix list:
    > S-OldNtlm                 GPO Default Domain Security Policy
    > S-ADRegistration          Function Resolve-S-ADRegistration 
#>
Function Resolve-S-ADRegistration {
    <#
        .SYNOPSIS
        Resolve the alert S-ADRegistration from PingCastle.

        .DESCRIPTION
        The purpose is to ensure that basic users cannot register extra computers in the domain.

        .NOTES
        Version 01.00.00 (2024/06/09 - Creation)
    #>

    Param()

    # Prepare for eventlog
    Test-EventLog | Out-Null
    $LogData = @('Fixing ms-DS-MachineAccountQuota to 0:')

    # Fixing the value
    Try {
        Set-ADDomain -Identity (Get-ADDomain) -Replace @{"ms-DS-MachineAccountQuota" = "0" } | Out-Null
        $LogData += '> Successfull <'
        $FlagRes = 'Info'
    }
    Catch {
        $LogData += @('! FAILED !',' ','Error message from stack:',$Error[0].ToString())
        $FlagRes = 'Error'
    }

    # Checking the new value - final check
    if ($FlagRes -eq 'Info') {
        $newValue = (Get-ADObject (Get-ADDomain).distinguishedName -Properties ms-DS-MachineAccountQuota).'ms-DS-MachineAccountQuota'

        if ($newValue -eq 0) {
            $LogData += @(' ','Value checked on AD: the value is as expected.')
        } 
        Else {
            $LogData += @(' ','Value checked on AD: the value is incorect!')
            $FlagRes = 'Warning'
        }
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}

Function Resolve-S-DC-SubnetMissing {
    <#
        .SYNOPSIS
        Resolve the S-DC-SubnetMissing alert from PingCastle.

        .DESCRIPTION
        Ensure that the minimum set of subnet(s) has been configured in the domain.

        .NOTES
        Version 01.00.00 (2024/06.09 - Creation)
    #>
    Param()

    #region INTERNAL FUNCTIONS
    function ConvertTo-IPv4MaskString {
        param(
          [Parameter(Mandatory = $true)]
          [ValidateRange(0, 32)]
          [Int] $MaskBits
        )
        $mask = ([Math]::Pow(2, $MaskBits) - 1) * [Math]::Pow(2, (32 - $MaskBits))
        $bytes = [BitConverter]::GetBytes([UInt32] $mask)
        (($bytes.Count - 1)..0 | ForEach-Object { [String] $bytes[$_] }) -join "."
      }
    #endregion
    # Init debug 
    Test-EventLog | Out-Null
    $LogData = @('Fixing missing DC subnet in AD Sites:')
    $FlagRes = "Info"

    # Get the DC IP address and subnet
    $DCIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' }
    
    #region ADD SUBNET
    # Get IP PLAN ADDRESSES and add them to the default AD Site
    foreach ($DCIP in $DCIPs) {
        Try {
            $IPplan = "$(([IPAddress] (([IPAddress] "$($DCIP.IPAddress)").Address -band ([IPAddress] (ConvertTo-IPv4MaskString $DCIP.PrefixLength)).Address)).IPAddressToString)/$($DCIP.PrefixLength)"
            $LogData += @(" ","Checking for IP Plan: $IPplan")
        }
        Catch {
            $LogData += @("Checking for IP Plan: $IPplan - FATAL ERROR",' ','Error message from stack:',$Error[0].ToString())
            $FlagRes += "Error"
        }
        
        # Check if the subnet already exists
        Try {
            $findSubnet = Get-AdReplicationSubnet $IPplan -ErrorAction Stop
        }
        Catch {
            $findSubnet = $null
        }

        if ($findSubnet) {
            $LogData += "Subnet $IPplan already exists (no action)"
        }
        Else {
            $LogData += "Subnet $IPplan is missing."
            $DfltSite = (Get-AdReplicationSite).Name
            Try {
                New-AdReplicationSubnet -Site (Get-AdReplicationSite).Name -Name $IPplan -ErrorAction Stop | Out-Null
                $LogData += "Subnet $IPplan has been added to '$DfltSite'"
            }
            Catch {
                $LogData += @("Subnet $IPplan could not be added to '$DfltSite'!")
                $FlagRes = "Error"
            }
        }
    }
    #endregion
    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}