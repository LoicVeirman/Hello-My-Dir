<#
    THIS MODULE CONTAINS FUNCTIONS ONLY USABLE BY HELLO MY DIR TO HARDEN A DIRECTORY.
#>
#region DOMAIN JOIN DELEGATION
Function Deploy-DomainJoinDelegation {
    <#
        .SYNOPSIS
        Allow a specific service account to join a computer to the domain.

        .DESCRIPTION
        Once the domain has been hardened, you can not join a computer to it if you do use an account member of "Protected Users".
        To circumvent this limitation, a sevice account will be created with the only permission to create a computer object in default location (CN=Computers).
        A group will also be created to manage delegation rights (and not assign this to a user object).

        .NOTES
        Version 01.00.00 (2024/06/20 - Creation)
    #>
    Param()
    
    #region INIT FUNCTION
    Test-EventLog | Out-Null
    $callStack = Get-PSCallStack
    $CalledBy = ($CallStack[1].Command -split '\.')[0]
    $ExitLevel = 'INFO'
    $DbgLog = @('START: Deploy-DomainJoinDelegation',' ',"Called by: $($CalledBy)",' ')
    #endregion

    #region CREATE GROUP
    #Create the new group for delegation puprose (it will be safe to rename it later, if needed)
    $GroupName = "LS-DLG-DomainJoin-Extended"
    $isPresent = Get-AdObject -LdapFilter "(&(ObjectClass=group)(SamAccountName=$GroupName))"
    if ($null -eq $isPresent) {
        Try {
            [void](New-ADGroup -Description "Group to join a computer to the domain (allowed to create the object)" `
                               -DisplayName $GroupName -GroupCategory Security -GroupScope DomainLocal `
                               -Name $GroupName -SamAccountName $GroupName)
            $DbgLog += @(' ',"Group '$GroupName' successfully created.")
        }
        Catch {
            $DbgLog += @(' ',"Failed to create the group '$GroupName'!","Error: $($_.ToString())")
            $ExitLevel = 'Error'
        }
    }
    Else {
        $DbgLog += @(' ',"Group '$GroupName' already exist (no change).")
    }
    #endregion

    #region CREATE USER
    $UserName = "DLGUSER01"
    $isPresent = Get-AdObject -LdapFilter "(&(ObjectClass=user)(SamAccountName=$UserName))"
    if ($null -eq $isPresent) {
        Try {
            [void](New-ADUser -Description "DLGUSER01 - Delegated User (domain joining)" -Name $UserName `
                              -SamAccountName $UserName -accountNotDelegated `
                              )
            $DbgLog += @(' ',"Group '$GroupName' successfully created.")
        }
        Catch {
            $DbgLog += @(' ',"Failed to create the group '$GroupName'!","Error: $($_.ToString())")
            $ExitLevel = 'Error'
        }
    }
    Else {
        $DbgLog += @(' ',"Group '$GroupName' already exist (no change).")
    }

    #endregion

}