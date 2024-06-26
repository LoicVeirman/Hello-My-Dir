<#
    THIS MODULE CONTAINS FUNCTIONS RELATED TO PINGCASTLE V3.2.0.1

    Initial Score: 65/100 (Stale: 31, Priv Accounts: 40, Trust: 00, Anomalies:65)
    Release Score: 05/100 (Stale: 00, Priv Accounts: 00, Trust: 00, Anomalies:05) - Will be 0 if you install a second DC
    Release ANSSI: Level 3
    Release MITRE: ATT&CK - 3 techniques matching for Credential access (DSheuristics, Auth.Users on DNS, Kerberos Armoring)


    Fix list:
    > S-OldNtlm                         GPO Default Domain Security
    > S-ADRegistration                  Function Resolve-SADRegistration 
    > S-DC-SubnetMissing                Function Resolve-SDCSubnetMissing
    > S-PwdNeverExpires                 Function Resolve-SPwdNeverExpires
    > P-Delegated                       Function Resolve-PDelegated
    > P-RecycleBin                      Function Resolve-PRecycleBin
    > P-SchemaAdmin                     Function Resolve-PSchemaAdmin
    > P-UnprotectedOU                   Function Resolve-PUnprotectedOU
    > A-LAPS-Not-Installed              Function Resolve-ALAPSNotInstalled & GPO Default Domain Security Policy
    > A-MinPwdLen                       Function Resolve-AMinPwdLen
    > A-DC-Spooler                      GPO Default Domain Controller Security
    > A-AuditDC                         GPO Default Domain Controller Security
    > A-DC-Coerce                       GPO Default Domain Controller Security
    > A-HardenedPaths                   GPO Default Domain Controller Security
    > A-NoServicePolicy                 Function Resolve-SPwdNeverExpires (add the requiered PSO)
    > A-PreWin2000AuthenticatedUsers    Function REsolve-APreWin2000AuthenticatedUsers
    > S-SMB-v1                          GPO Default Domain Security
#>
#region S-ADRegistration
Function Resolve-SADRegistration {
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
#endregion
#region S-DC-SubnetMissing
Function Resolve-SDCSubnetMissing {
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
#endregion
#region S-DC-SubnetMissingIPv6
Function Resolve-SDCSubnetMissingIPv6 {
    <#
        .SYNOPSIS
        Disable IPv6 on the local system.

        .DESCRIPTION
        Check for any interface setup for IPv6 and disable IPv6 on it.

        .NOTES
        Version 01.00.00 (2024/06/15 - Creation)
    #>
    Param()

    # Init debug 
    Test-EventLog | Out-Null
    $LogData = @('Disabling IPv6:',' ')
    $FlagRes = "Info"

    Try {
        Get-NetAdapterBinding -ComponentID "ms_tcpip6" | Where-Object { $_.Enabled -eq $true } | Disable-NetAdapterBinding -ComponentID "ms_tcpip6"
        $LogData += "ms_tcpip6 disabled on all interfaces."
    }
    Catch {
        $LogData += @("Failed to disable ms_tcpip6 on all interfaces.","Error: $($_.ToString())")
        $FlagRes = "Error"
    }
    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region S-PwdNeverExpires
Function Resolve-SPwdNeverExpires {
    <#
        .SYNOPSIS
        Resolve the S-PwdNeverExpires alert from PingCastle.

        .DESCRIPTION
        Ensure that every account has a password which is compliant with password expiration policies.
        To achieve this goal, some PSO will be added to the domain, including one specific to the emergency accounts.

        PSO List:
        > PSO-EmergencyAccounts-LongLive......: 5 years,  complex, 30 characters, Weight is 105.
        > PSO-ServiceAccounts-Legacy..........: 5 years,  complex, 30 characters, Weight is 105.
        > PSO-EmergencyAccounts-Standard......: 1 year,   complex, 30 characters, Weight is 100.
        > PSO-Users-ChangeEvery3years.........: 3 year,   complex, 16 characters, Weight is 70.
        > PSO-Users-ChangeEvery1year..........: 1 year,   complex, 12 characters, Weight is 60.
        > PSO-Users-ChangeEvery3months........: 3 months, complex, 10 characters, Weight is 50.
        > PSO-ServiceAccounts-ExtendedLife....: 3 years,  complex, 18 characters, Weight is 35.
        > PSO-ServiceAccounts-Standard........: 1 year,   complex, 16 characters, Weight is 30.
        > PSO-AdminAccounts-SystemPriveleged..: 6 months, complex, 14 characters, Weight is 20.
        > PSO-AdminAccounts-ADdelegatedRight..: 6 months, complex, 16 characters, Weight is 15.
        > PSO-ServiceAccounts-ADdelegatedRight: 1 year,   complex, 24 characters, Weight is 15.
        > PSO-AdminAccounts-ADhighPrivileges..: 6 months, complex, 20 characters, Weight is 10.

        To learn how thos PSO should be used in production, please have a look to the documentation (PSO Managegement.md)

        .NOTES
        Version 01.00.00 (2024/06/10 - Creation)
    #>
    Param()
    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Adding PSO to the domain:')
    $FlagRes = "Info"

    # Load XML data
    $psoXml = Get-XmlContent .\Configuration\DomainSettings.xml

    # Retrieving SID 500 SamAccountName
    $Sid500 = (Get-ADUser -Identity "$((Get-AdDomain).domainSID)-500").SamAccountName

    # Looping on PSO list
    foreach ($PSO in $psoXml.Settings.PwdStrategyObjects.PSO) {
        #region Create AD Group
        $LogData += " "
        $GrpExists = Get-ADGroup -LDAPFilter "(SAMAccountName=$($PSO.Name))"
        if ($GrpExists) {
            $LogData += "$($PSO.Name): Group already exists."
        }
        Else {
            Try {
                New-ADGroup -DisplayName $PSO.Name -Description "Group to assign the PSO: $($PSO.Name)"  -GroupCategory Security -GroupScope Global -Name $PSO.Name -ErrorAction Stop | Out-Null
                $LogData += "$($PSO.Name): Group created successfully."
            }
            Catch {
                $LogData += "$($PSO.Name): Group could not be created!"
                $FlagRes = "Error"
            }
        }
        #endregion
        #region Checking if member is to be added
        if ($PSO.Member) {
            foreach ($Member in $PSO.Member) {
                if ($Member -eq 'SID-500') {
                    $MbrSam = $Sid500
                }
                Else {
                    $MbrSam = $Member
                }
                Try {
                    Add-ADGroupMember -Identity $PSO.Name -Members $MbrSam -ErrorAction Stop | Out-Null
                    $LogData += "$($PSO.Name): successfully added $MbrSam to the PSO group."
                }
                Catch {
                    $LogData += "$($PSO.Name): failed to add $MbrSam to the PSO group!"
                    $FlagRes = "Error"
                }
                Try {
                    if ((Get-ADObject -Filter "SamAccountName -eq '$MbrSam'").ObjectClass -eq 'User') {
                        Set-AdUser $MbrSam -PasswordNeverExpires 0 | Out-Null
                        $LogData += "$($PSO.Name): User $MbrSam has been set with PasswordNeverExpires to $False"
                    }
                }
                Catch {
                    $LogData += "$($PSO.Name): Failed to set password expiration to $mbrSam!"
                }
            }
        }
        #endregion
        #region Create new PSO
        Try {
            if ((Get-ADObject -LDAPFilter "(&(name=$($PSO.Name))(ObjectClass=msDS-PasswordSettings))")) {
                $LogData += "$($PSO.Name): PSO already exists."
            }
            Else {
                new-adFineGrainedPasswordPolicy -ComplexityEnabled 1 `
                                                -Description ((($PSO.Name).Replace('PSO-','PSO for ')).Replace('-',' ')) `
                                                -DisplayName $PSO.Name `
                                                -LockOutDuration "0.0:30:0.0" `
                                                -LockoutObservationWindow "0.0:30:0.0" `
                                                -LockoutThreshold 5 `
                                                -MaxPasswordAge $PSO.MaxPwdAge `
                                                -MinPasswordAge "1.0:0:0.0" `
                                                -MinPasswordLength $PSO.PwdLength `
                                                -Name $PSO.Name `
                                                -PasswordHistoryCount 60 `
                                                -Precedence $PSO.Precedence `
                                                -ProtectedFromAccidentalDeletion 1 `
                                                -ReversibleEncryptionEnabled 0 `
                                                -OtherAttributes @{'msDS-PSOAppliesTo'=(Get-AdGroup $PSO.Name).distinguishedName} `
                                                -ErrorAction Stop | Out-Null

                $LogData += "$($PSO.Name): PSO successfully created."
            }
        }
        Catch {
            $LogData += "$($PSO.Name): PSO could not be created!"
            $FlagRes = "Error"
        }
        #endregion
    }
    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region P-Delegated
Function Resolve-PDelegated {
    <#
        .SYNOPSIS
        Reolve the P-Delegated alert from PingCastle.

        .DESCRIPTION
         Ensure that all Administrator Accounts have the configuration flag "this account is sensitive and cannot be delegated" (or are members of the built-in group "Protected Users" when your domain functional level is at least Windows Server 2012 R2).

        .NOTES
        Version 01.00.00 (2024/06/10 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Setting "Account is sensible and cannot be delegated" to empowered users:')
    $FlagRes = "Info"

    # Getting all empowered users, except KRBTGT
    Try {
        $myAdmin = "$((Get-AdDomain).DomainSID)-500"
        Set-AdUser $myAdmin -AccountNotDelegated 1 -ErrorAction Stop | Out-Null
        $LogData += "$($MyAdmin.Name): successfully set AccountNotDelegated to 1"
    }
    Catch {
        $LogData += @("$($MyAdmin.Name): failed tp set AccountNotDelegated to 1!",' ',"Error: $($_.ToString())")
        $FlagRes = "Error"
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region P-RecycleBin
Function Resolve-PRecycleBin {
    <#
        .SYNOPSIS
        Resolve the alert P-RecycleBin from PingCastle.

        .DESCRIPTION
        Ensure that the Recycle Bin feature is enabled.

        .NOTES
        Version 01.00.00 (2024/06/10 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Enabling AD RecycleBin (if needed)')
    $FlagRes = "Info"

    # Load XML data
    $RunSetup = Get-XmlContent .\Configuration\RunSetup.xml

    # Check if Recycle Bin was to enable
    $installRB = $RunSetup.Configuration.Forest.RecycleBin

    # If tasked to be installed in the forest, then doing precheck and enabling.
    if ($installRB -eq 'Yes') {
        # Am I in a child domain? If so, I don't care about RB.
        if ($RunSetup.Configuration.Domain.Type -eq 'Root') {
            # We also need to ensure that the forest level is at least 2008 R2
            if ([int]$RunSetup.Configuration.Forest.FunctionalLevel -ge 4) {
                # So far, so good... Let's enable it.
                Try {
                    if ((Get-ADOptionalFeature -Filter 'name -like "Recycle Bin Feature"').EnabledScopes) {
                        $LogData += "The AD REcycle Bin is already enabled."
                    }
                    Else {
                        Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target (Get-ADForest).Name -WarningAction SilentlyContinue -Confirm:$false | Out-Null
                        $LogData += "The AD Recycle Bin is now enabled."
                    }
                }
                Catch {
                    $LogData += "Failed to enable the AD Recycle Bin!"
                    $FlagRes = "Error"
                }
            } 
            Else {
                $LogData += "The Forest Functional Level is lower than 4 (2008R2): no Recycle Bin activation could be performed."
                $FlagRes = "Warning"    
            }
        }
        Else {
            $LogData += "This is a $($RunSetup.Configuration.Domain.Type) domain: no Recycle Bin activation needed (forest level)."
            $FlagRes = "Warning"
        }
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region P-SchemaAdmin
Function Resolve-PSchemaAdmin {
    <#
        .SYNOPSIS
        Resolve the alert P-SchemaAdmin from PingCastle.

        .DESCRIPTION
        Ensure that no account can make unexpected modifications to the schema.

        .NOTES
        Version 01.00.00 (2024/06/10 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Dropping any account from the Schema Admins group')
    $FlagRes = "Info"

    # Remove all members
    Try {
        $Members = Get-AdGroupMember "$((Get-AdDomain).DomainSID)-518"
        if ($null -ne $Members) {
            remove-adGroupMember -Identity "$((Get-AdDomain).DomainSID)-518" -Members $Members -ErrorAction Stop -Confirm:$false | Out-Null
            $LogData += "Successfully removed all members from Schema Admins group."
        }
    }
    Catch {
        $LogData += "Failed to remove all members from Schema Admins group!"
        $FlagRes = "Error"
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region P-UnprotectedOU
Function Resolve-PUnprotectedOU {
    <#
        .SYNOPSIS
        Resolve the alert P-UnprotectedOU from PingCastle.

        .DESCRIPTION
        Ensure that Organizational Units (OUs) and Containers in Active Directory are protected to prevent accidental deletion, which could lead to data loss and disruptions in the network infrastructure.

        .NOTES
        Version 01.00.00 (2024/06/10 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Securing Organizational Units against accidental deletion:')
    $FlagRes = "Info"

    # Find OU without the option "protected against accidental deletion"
    $UnprotectedOU = Get-ADOrganizationalUnit -filter {name -like "*"} -Properties ProtectedFromAccidentalDeletion

    # Looping around...
    foreach ($OU in $UnprotectedOU) {
        $LogData += " "
        Try {
            Set-ADOrganizationalUnit -ProtectedFromAccidentalDeletion $true -Identity $OU.DistinguishedName -ErrorAction Stop | Out-Null
            $LogData += "$($OU.DistinguishedName): successfully protected against accidental deletion."
        }
        Catch {
            $LogData += "$($OU.DistinguishedName): failed to protect against accidental deletion!"
        }
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region A-MinPwdLen
Function Resolve-AMinPwdLen {
    <#
        .SYNOPSIS
        Resolve the alert A-MinPwdLen from PingCastle.

        .DESCRIPTION
        Verify if the password policy of the domain enforces users to have at least 8 characters in their password

        .NOTES
        Version 01.00.00 (2024/06/10 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Modifying default password strategy to x char (based on domainSettings.xml):')
    $FlagRes = "Info"

    # Load XML
    $DomainSettings = Get-XmlContent .\configuration\DomainSettings.xml

    # Get default value (if less than 8, then forced to 8)
    if ([int]$DomainSettings.Settings.DefaultPwdStrategy.PwdLength -ge 8) {
        $newLen = [int]$DomainSettings.Settings.DefaultPwdStrategy.PwdLength
    } 
    Else {
        $newLen = 8
    }
    $LogData += "New Default Domain Policy password length value: $newLen"

    # Update the policy: Windows Server 2022
    Try {
        $FlagIs2k22 = $False
        if ((gwmi Win32_OperatingSystem).Caption -match "2022") {
            $FlagIs2k22 = $true
            Set-ADDefaultDomainPasswordPolicy -ComplexityEnabled 1 -Confirm:$false -Identity (Get-ADDomain).DistinguishedName `
                                              -LockOutDuration 0.0:15:0.0 -LockoutObservationWindow 0.0:5:0.0 -LockoutThreshold 5 `
                                              -MaxPasswordAge 365.0:0:0.0 -MinPasswordAge 1.0:0:0.0 -MinPasswordLength $newLen `
                                              -PasswordHistoryCount 24 -ReversibleEncryptionEnabled 0 
            
            $LogData += @("Using Set-ADDefaultDomainPasswordPolicy:",' ',"Complexity: Enabled", "Lockout duration: 15 min.", "Lockout observation: 5 min.", "Lockout threshold: 5", "Max pwd age: 365 days", "Min pwd age: 1 day", "Password Min Length: $newLen", "Password History: 24", "Reversible encryption: False")
        }
        Else {
            $LogData += "Sorry, this function does not handle OS release beneath Windows Server 2022. Will try to set this up by manipulating secpol..."
        }
    }
    Catch {
        $LogData += @("Failed to update the default password strategy for your domain!","Error: $($_.ToString())")
        $FlagRes = "Error"
    }

    # Update the policy: Windows Server 2019 or younger
    Try {
        if (-not($FlagIs2k22)) {
            [void](secedit /export /cfg .\secpol.cfg)
            [void]((Get-Content .\secpol.cfg).replace("MaximumPasswordAge = 42", "MaximumPasswordAge = 365") | Out-File .\secpol.cfg)
            [void]((Get-Content .\secpol.cfg).replace("MinimumPasswordLength = 7", "MinimumPasswordLength = $NewLen") | Out-File .\secpol.cfg)
            [void](secedit /configure /db c:\windows\security\local.sdb /cfg .\secpol.cfg /areas SECURITYPOLICY)
            [void](rm -force .\secpol.cfg -confirm:$false)

            $LogData += @("Using SECPOL:",' ',"Complexity: Enabled", "Lockout duration: N/A", "Lockout observation: N/A", "Lockout threshold: 0", "Max pwd age: 365 days", "Min pwd age: 1 day", "Password Min Length: $newLen", "Password History: 24", "Reversible encryption: False")
        }
        Else {
            if (-not($FlagIs2k22)) {
                $LogData += "Failed to identify how to setup the default password strategy!"
                $FlagRes = "Warning"
            }
        }
    }
    Catch {
        $LogData += @("Failed to update the default password strategy for your domain!","Error: $($_.ToString())")
        $FlagRes = "Error"
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region A-PreWin2000AuthenticatedUsers
Function Resolve-APreWin2000AuthenticatedUsers {
    <#
        .SYNOPSIS
        Resolve the alert A-PreWin2000AuthenticatedUsers from PingCastle.

        .DESCRIPTION
        Ensure that the "Pre-Windows 2000 Compatible Access" group does not contains "Authenticated Users".

        .NOTES
        Version 01.00.00 (2024/06/10 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @("Dropping content from 'Pre-Windows 2000 Compatible Access':")
    $FlagRes = "Info"

    # Flubbing the group
    Try {
        Set-adGroup -Identity "S-1-5-32-554" -Clear member
        $LogData += "Group S-1-5-32-554 flushed."
    }
    Catch {
        $LogData += "Group S-1-5-32-554 could not be flushed!"
        $FlagRes = "Error"
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion
#region A-LAPS-NOT-Installed
Function Resolve-ALAPSNotInstalled {
    <#
        .SYNOPSIS
        This function resolve the alert A-LAPS-NOT-Installed from PingCastle.

        .DESCRIPTION
        Ensure that LAPS is in place for the whole domain. If the DFL and/or OS.Caption does not meet minimum requierement for Windows LAPS, 
        the script will the deploy the MS LAPS binaries (legacy mode).

        .EXTERNALHELP
        https://learn.microsoft.com/fr-fr/windows-server/identity/laps/laps-scenarios-windows-server-active-directory

        .NOTES
        Version 01.00.00 (2024/06/12 - Creation)
    #>
    Param()

    # Logs
    Test-EventLog | Out-Null
    $LogData = @('Enable LAPS on your domain:', ' ')
    $FlagRes = "Info"

    # Get DC OS Caption and DFL.
    $OSCaption = (gwmi Win32_OperatingSystem).Caption
    $DomainDFL = (Get-AdDomain).DomainMode
    $OSArchitr = (gwmi Win32_OperatingSystem).OSArchitecture

    $LogData += @("OS Caption: $($OSCaption)","Domain Functional Level: $($DomainDFL)","OS Architecture: $($OSArchitr)",' ')

    # Updating Schema, if possible
    if (($OSCaption -match '2019' -or $OSCaption -match '2022') -and ($DomainDFL -match '2016')) {
        $LogData += @("The prerequesite to Windows LAPS are fullfilled."," ")
        Try {
            [void](Update-LapsADSchema -Confirm:$false -ErrorAction Stop)
            $LogData += @("AD Schema extended with Windows LAPS.","Beware: the extension does not implies automatic activation.","Please ensure the GPO Default Domain Security is propperly setup.",' ')
        }
        Catch {
            $FlagRes = "Error"
            $LogData += @("Failed to extend the schema!","Error: $($_.ToString())",' ')
        }
    }
    Else {
        $LogData += @("The prerequesite to Windows LAPS are not fullfilled (OS not 2019+ and/or DFL not 2016)"," ")
        Try {
            if ($OSArchitr -match '64') {
                [void](Start-Process -FilePath "$env:systemroot\system32\msiexec.exe" -WorkingDirectory ".\IMPORTS\MS LAPS" -ArgumentList '/i laps.x64.msi ADDLOCAL=Management.UI,Management.PS,Management.ADMX /quiet /norestart' -NoNewWindow -Wait -ErrorAction Stop)
            }
            Else {
                [void](Start-Process -FilePath "$env:systemroot\system32\msiexec.exe" -WorkingDirectory ".\IMPORTS\MS LAPS" -ArgumentList '/i laps.x86.msi ADDLOCAL=Management.UI,Management.PS,Management.ADMX /quiet /norestart' -NoNewWindow -Wait -ErrorAction Stop)
            }
            $LogData += @("MS LAPS installed.",' ')
        }
        Catch {
            $LogData += @("Failed to install MS LAPS binaries!","Error: $($_.ToString())"," ")
            $FlagRes = "Error"
        }
        if ($FlagRes -eq 'Info') {
            # Extending Schema
            Try {
                [void](Import-Module AdmPwd.PS -ErrorAction Stop -WarningAction Stop)
                [void](Update-AdmPwdADSchema -ErrorAction Stop)
                $LogData += @("Schema updated for MS LAPS successfully.",' ')
            }
            Catch {
                $LogData += @("Failed to update the Schema for MS LAPS!","Error: $($_.ToString())",' ')
                $FlagRes = "Error"
            }
        }
    }

    $LogData += 'Please note that this script do not enable any permission - you still have to setup LAPS to match your needs.'
    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes
}
#endregion