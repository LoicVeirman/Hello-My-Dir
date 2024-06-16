<#
    THIS MODULE CONTAINS FUNCTIONS RELATED TO PURPLE KNIGHT V4.2

    Initial Score: 98/100 (AD DElegation: 100, Account Security:  99, AD Infrastructure Security:  99, Group Policy Security: 100, Kerberos Security:  99, Hybrid: N/A)
    Release Score: ??/100 (AD DElegation: 100, Account Security: ..., AD Infrastructure Security: ..., Group Policy Security: 100, Kerberos Security: ..., Hybrid: N/A)
    Release ANSSI: Level 02

    Disabled Test:
    > Permission changes on AdminSDHolder object                                                    Alert expected: the domain has just been built.
    > gMSA not in use                                                                               Alert expected: there is no need of gMSA at this stage.
    > Built-in domain Administrator account used within the last two weeks                          Alert expected: this is the only account.
    > Changes to privileged group membership in the last 7 days                                     Alert expected: the domain has just been built.
    > Changes to Default Domain Policy or Default Domain Controllers Policy in the last 7 days      Alert expected: the domain has just been built.

    Fix list:
    > LDAP signing is not required on Domain Controllers                    Function Resolve-LDAPSrequired & GPO Default Domain Security & GPO Default Domain Controllers Security
    > RC4 or DES encryption type are supported by Domain Controllers        GPO Default Domain Controllers Security
    > Protected Users group not in use                                      Function Resolve-ProtectedUsers
#>
#region PK LDAPS REQUIERED
Function Resolve-LDAPSrequired {
    <#
        .SYNOPSIS
        Create a self-signed certificate on DC for LDAPS purpose.

        .DESCRIPTION
        As the domain is a fresh built one, there is no pki or whatever. A self-signed certificate will allow this DC to use LDAPS.

        .NOTES
        Version 01.00.00 (2024/06/16 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Create a Self-Signed certificate for LDAPS:',' ')
    $FlagRes = "Info"

    # Retrieve DC data
    $DCfullname = "$($env:ComputerName).$($env:UserDNSdomain)"
    $DCname = $env:ComputerName
    $LogData += @("DNS Name will be $DCfullname.","Certificate name will be $DCname.",' ')

    # Generate New Cert
    Try {
        $myCert = New-SelfSignedCertificate -DnsName $DCfullname, $DCname -CertStoreLocation cert:\LocalMachine\My -ErrorAction Stop
        $LogData += @('Certificate successfully generated.',"Command: New-SelfSignedCertificate -DnsName $DCfullname, $DCname -CertStoreLocation cert:\LocalMachine\My -ErrorAction Stop",' ')
    }
    Catch {
        $FlagRes = "Error"
        $LogData += @("Failed to generate the certificate!","Error: $($_.ToString())")
    }

    # Moving cert to Trusted Root
    Try {
        $CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList 'Root','LocalMachine'
        $CertStore.Open('ReadWrite')
        
        $LogData += @('CertStore LocalMachine\Root open in read/write successfully.',' ')

        $Certificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $_.thumbprint -eq $myCert.Thumbprint }
        if ($Certificate) {
            $LogData += @("Certificate $DCName found in LocalMachine\My.","Thumbprint: $($Certificate.Thumbprint)")

            [void]$CertStore.Add($Certificate)
            [void]$CertStore.Close()

            $LogData += @("Certificate $DCName copied to LocalMachine\Root.",' ')
        }
        Else {
            $LogData += @("Certificate $DCName not found in LocalMachine\My!","Error: $($_.ToString())")
            $FlagRes = "Error"
        }
    }
    Catch {
        $LogData += @("Certificate $DCName failed to be copied in LocalMachine\Root!","Error: $($_.ToString())")
        $FlagRes = "Error"
    }
    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes 
}
#endregion

#region PK Protected Users
Function Resolve-ProtectedUsers {
    <#
        .SYNOPSIS
        Function to fix the alert "protected users not in use" from Purple Knight.

        .DESCRIPTION
        This function add the administrator account to the protected users group.

        .NOTES
        Version 01.00.00 (2024/06/16 - Creation)
    #>
    Param()

    # Prepare logging
    Test-EventLog | Out-Null
    $LogData = @('Add Administrator to Protected Users:',' ')
    $FlagRes = "Info"

    # Adding administrator to PUG.
    Try {
        [void](Add-AdGroupMember -identity "Protected Users" -Members (Get-AdUser "$((Get-AdDomain).DomainSID)-500") -ErrorAction Stop)
        $LogData += "Account successfully added."
    }
    Catch {
        $LogData += @("Failed to add the account to the group!"," ","Error: $($_.ToString())")
        $FlagRes = "Error"
    }

    # Sending log and leaving with proper exit code
    Write-ToEventLog $FlagRes $LogData
    Return $FlagRes 

}
#endregion