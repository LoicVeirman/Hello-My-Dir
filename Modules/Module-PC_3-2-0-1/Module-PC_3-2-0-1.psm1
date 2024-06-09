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

}