<#
    .Synopsis
    Prepare system ofr a test run
#>

Param(
    [switch]$KeepRunSetup,
    [switch]$RemovePrerequesite,
    [string]$InstallPath = "C:\HmD"
)

# Backup config file
if ($KeepRunSetup) {   
    if (Test-Path $InstallPath\Configuration\RunSetup.xml) {
    $backup = [XML](get-content $InstallPath\Configuration\RunSetup.xml -Encoding UTF8)
    }
}

# Updating binaries
Robocopy.exe "$((Get-Location).Path)" "$($InstallPath)" /MIR

# Restore config file
if ($KeepRunSetup) {   
        $backup | Out-File $InstallPath\Configuration\RunSetup.xml -Encoding UTF8
    }

# Cleaning up any existing ADDS installation (and reboot if needed)
Try {
    [void]($DCinstalled = Get-AdDomain -ErrorAction Stop)
}
Catch {
    $DCinstalled = $null
}
if ($DCinstalled) {
    Try {
        Uninstall-ADDSdomainController -LastDomainControllerInDomain -LocalAdministratorPassword (ConvertTo-SecureString -AsPlainText "C1mo2pasS==" -Force) -NoRebootOnCompletion -ErrorAction Stop
    }
    Catch {
        Write-Warning "Failed to uninstall ADDS: $($_.ToString())"
    }
}

if ($RemovePrerequesite) {
    #Dealing with binaries to uninstall
    $reqBinaries = @('AD-Domain-Services', 'RSAT-AD-Tools', 'RSAT-DNS-Server', 'RSAT-DFS-Mgmt-Con', 'GPMC')
    $ProgressPreference = "SilentlyContinue"

    foreach ($ReqBinary in $reqBinaries) {
        Try {
            Uninstall-WindowsFeature -Name $ReqBinary -IncludeManagementTools -ErrorAction Stop
        }
        Catch {
            Write-Warning "Failed to uninstall $ReqBinary (error: $($_.ToString()))"
        }
    }
}

exit 0