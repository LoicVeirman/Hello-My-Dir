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
    $randomSMpwd = New-RandomComplexPasword -Length 24 -AsClearText
    $UserName = "DLGUSER01"
    $isPresent = Get-AdObject -LdapFilter "(&(ObjectClass=user)(SamAccountName=$UserName))"
    if ($null -eq $isPresent) {
        Try {
            [void](New-ADUser -Description "DLGUSER01 - Delegated User (domain joining)" `
                              -Name $UserName -DisplayName $UserName `
                              -SamAccountName $UserName -accountNotDelegated 1 `
                              -AccountPassword  (ConvertTo-SecureString -AsPlainText $randomSMpwd -Force) `
                              -Enabled 1 -GivenName "Delegate" -Surname "USER 01" -KerberosEncryptionType AES128 `
                              -TrustedForDelegation 0 -UserPrincipalName "$Username@$((Get-AdDomain).DnsRoot)")
            $DbgLog += @(' ',"User '$Username' successfully created.")

            # Show password to user
            Add-Type -AssemblyName System.Windows.Forms
            [void]([System.Windows.Forms.MessageBox]::Show("$UserName password: $randomSPpwd","Warning"))
        }
        Catch {
            $DbgLog += @(' ',"Failed to create the user '$UserName'!","Error: $($_.ToString())")
            $ExitLevel = 'Error'
        }
    }
    Else {
        $DbgLog += @(' ',"User '$UserName' already exist (no change).")
    }
    #endregion

    #region ADD USER TO GROUPS
    $psoXml = Get-XmlContent .\Configuration\DomainSettings.xml
    $GroupList = @((Select-Xml $psoXml -XPath "\\PSO[@Ref='PsoSvcStd']" | Select-Object -ExpandProperty Node).Name, $GroupName)

    foreach ($Group in $GroupList) {
        $isMember = (Get-AdGroupMember $Group).SamAccountName -contains $UserName
        if ($isMember) {
            $DbgLog += @(' ',"User $Username is already member of $Group.")
        }
        Else {
            Try {
                [void](Add-AdGroupMember -Identity $Group -Members $UserName -ErrorAction Stop)
                $DbgLog += @(' ',"User $Username has been added to the group $group.")
            }
            Catch {
                $DbgLog += @(' ',"Failed to add $Username to the group $group!","Error: $($_.ToString())")
                $ExitLevel = "Error"
            }
        }
    }
    #endregion

    #region SET DELEGATION
    $Container = (Get-ADDomain).ComputersContainer
    Try {
        Push-Location AD:

        $inheritanceguid = New-Object Guid 00000000-0000-0000-0000-000000000000
        $Objectguid = New-Object Guid bf967a86-0de6-11d0-a285-00aa003049e2
        $group = Get-ADGroup $GroupName
        $SID = New-Object System.Security.Principal.SecurityIdentifier $($group.SID)
        $identity = [System.Security.Principal.IdentityReference] $SID
        $adRights = [System.DirectoryServices.ActiveDirectoryRights] "CreateChild, DeleteChild"
        $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
        $type = [System.Security.AccessControl.AccessControlType] "Allow"
        $Parameters = $identity, $adRights, $type, $Objectguid, $inheritanceType, $inheritanceguid
        $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Parameters)
        $acl = Get-Acl "AD:\$Container" -ErrorAction Stop
        $acl.AddAccessRule($ace)
        Set-Acl -AclObject $acl -Path "AD:\$Container" -ErrorAction Stop

        $inheritanceguid = New-Object Guid bf967a86-0de6-11d0-a285-00aa003049e2
        $Objectguid = New-Object Guid 00000000-0000-0000-0000-000000000000
        $group = Get-ADGroup $GroupName
        $SID = New-Object System.Security.Principal.SecurityIdentifier $($group.SID)
        $identity = [System.Security.Principal.IdentityReference] $SID
        $adRights = [System.DirectoryServices.ActiveDirectoryRights] "CreateChild, DeleteChild"
        $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "Descendents"
        $type = [System.Security.AccessControl.AccessControlType] "Allow"
        $Parameters = $identity, $adRights, $type, $Objectguid, $inheritanceType, $inheritanceguid
        $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Parameters)
        $acl = Get-Acl "AD:\$Container" -ErrorAction Stop
        $acl.AddAccessRule($ace)
        Set-Acl -AclObject $acl -Path "AD:\$Container" -ErrorAction Stop

        Pop-Location

        $DbgLog += @(' ',"Successfully delegated rights on computer object to $GroupName at $Container.")
    }
    Catch {
        $DbgLog += @(' ',"Failed to delegate rights on computer object to $GroupName at $Container!","Error: $($_.ToString())")
        $ExitLevel = "Error"
    }
    #endregion
    
    #region RETURN RESULT
    Write-ToEventLog $ExitLevel $DbgLog
    Return $ExitLevel
    #endregion
}
#endregion