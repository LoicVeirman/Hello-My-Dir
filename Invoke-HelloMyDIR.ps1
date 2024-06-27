<#
    .SYNOPSIS
    This is the main script of the project "Hello my Dir!".

    .COMPONENT
    PowerShell v5 minimum.

    .DESCRIPTION
    This is the main script to execute the project "Hello my Dir!". This project is intended to ease in building a secure active directory from scratch and maintain it afteward.

    .PARAMETER Prepare
    Instruct the script to create or edit the setup configuration file (RunSetup.xml).

    .PARAMETER AddDC
    Instruct the script to add a new DC to your domain.

    .PARAMETER NewDCname
    Specify your new DC name, if you need to rename it before promoting.

    .EXAMPLE
    .\Invoke-HelloMyDir.ps1 -Prepare
    Will only query for setup data (generate the RunSetup.xml file). 

    .EXAMPLE
    .\Invoke-HelloMyDir.ps1
    Will run the script for installation purpose (or failed if not RunSetup.xml is present). 

    .EXAMPLE
    .\Invoke-HelloMyDir.ps1 -AddDC
    Will run the script to empower the system as a new DC in an existing forest.

    .EXAMPLE
    .\Invoke-HelloMyDir.ps1 -AddDC -NewDCname 'SRV-ADDS-02'
    Will run the script to empower the system as a new DC in an existing forest and name the new DC as SRV-ADDS-02.

    .NOTES
    Version.: 01.01.000
    Author..: Loic VEIRMAN (MSSec)
    History.: 
    01.00.000   Script creation.
    01.01.000   Hello my DC - Add a DC to your forest.
#>
[CmdletBinding(DefaultParameterSetName = 'NewForest')]
Param(
    [Parameter(Position=0, ParameterSetName = 'NewForest')]
    [switch]
    $Prepare,

    [Parameter(Position=1, ParameterSetName = 'NewDC')]
    [switch]
    $AddDC
)
#region Script Initialize
# Load modules. If a module fails on load, the script will stop.
Try {
    Import-Module -Name (Get-ChildItem .\Modules).FullName -ErrorAction Stop | Out-Null
}
Catch {
    Write-Error "Failed to load modules."
    Write-Host "`nError Message: $($_.ToString())`n" -ForegroundColor Yellow
    Exit 1
}

# Initiate logging
$DbgLog = @('START: invoke-HelloMyDir')
Test-EventLog | Out-Null

if ($Prepare) {
    $DbgLog += 'Option "Prepare" declared: the file RunSetup.xml will be generated'
} 
if ($AddDC) {
    $DbgLog += 'Option "AddDC" declared: the file RunSetup.xml will be used to promote the system as a DC'
    $DbgLog += "Option NewDCname is equal to '$NewDCname'."
} 
if (-not($Prepare) -and -not($AddDC)) {
    $DbgLog += 'No option used: the setup will perform action to configure your AD (first DC in a brand new domain).'
}

# CHECK FOR FIRST RUN
if (-not(Test-Path .\Configuration\RunSetup.xml)) {
    $DbgLog += 'No option used: as the file RunSetup.xml is missing, the script will enfore -Prepare to True.'
    New-HMDRunSetupXml | Out-Null
    $Prepare = $true
}

Write-toEventLog -EventType INFO -EventMsg $DbgLog | Out-Null
$DbgLog = $null

# Create result text array
$arrayRsltTxt = @('RUNNING','SUCCESS',' ERROR ','SKIPPED','WARNING')
$arrayColrTxt = @('Gray','Green','Red','cyan','Yellow')

# Load Script Settings XML
$ScriptSettings = Get-XmlContent .\Configuration\ScriptSettings.xml

# Say Hello: Write Header
Clear-Host
$ScriptTitle = @(' ',"$([Char]0x2554)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2557)" `
                    ,"$([Char]0x2551) Hello My DIR! $([Char]0x2551)" `
                    ,"$([Char]0x2551) version 1.1.0 $([Char]0x2551)" `
                    ,"$([Char]0x2551) Lic. GNU GPL3 $([Char]0x2551)" `
                    ,"$([Char]0x255A)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x255D)" `
                    ,' ')
Write-TitleText -Text $ScriptTitle

# Say Hello: Display welcome text
$toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='000']" | Select-Object -ExpandProperty Node
$toDisplayArr = @($toDisplayXml.Line1)
if ($toDisplayXml.Line2) {
    $toDisplayArr += @($toDisplayXml.Line2)
}
if ($toDisplayXml.Line3) {
    $toDisplayArr += @($toDisplayXml.Line3)
}
if ($toDisplayXml.Line4) {
    $toDisplayArr += @($toDisplayXml.Line4)
}
Write-InformationalText -Text $toDisplayArr
Write-Host
#endregion

#region USE CASE 1: PREPARE XML SETUP FILE
if ($Prepare) {
    # Test if a configuration file already exists - if so, we will use it.
    $DbgLog = @('PHASE INIT: LOAD PREVIOUS CHOICE SELECTION.')

    if (Test-Path .\Configuration\RunSetup.xml) {
        # A file is present. We will rename it to a previous version to read old values and offers them as default option.
        $DbgLog += 'The file ".\Configuration\RunSetup.xml" is present.'
        # Loading .last file as default option for the script.
        Try {
            $RunSetup = Get-XmlContent .\Configuration\RunSetup.xml -ErrorAction SilentlyContinue
            $DbgLog += '{RunSetup} now contains previous selection.'
            $DbgType = 'INFO'
        }
        Catch {
            $DbgLog += '{RunSetup} could not be loaded from runSetup.xml!'
            $DbgType = 'ERROR'
        }
    }
    Else {
        $DbgLog += 'The file ".\Configuration\RunSetup.xml" is missing!'
        $DbgType = 'ERROR'
    }
    Write-toEventLog $DbgType $DbgLog | Out-Null
    $DbgLog = $null

    if ($DbgType -eq 'ERROR') {
        # This is an unrecoverable error. The script leaves.
        Write-toEventLog -EventType INFO -EventMsg "END: invoke-HelloMyDir"
        Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
        Write-Error "The script match an unrecoverable error, please review logs for further details."
        Exit 2
    }

    # Inquiring for setup data: Forest
    $DbgLog = @("SETUP DATA COLLECT:"," ")

    ## Is it a new forest?
    ### Calling Lurch from Adam's family...
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

    ### Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='001']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
    
    ### Yes/No time
    ### Get current cursor position and create the Blanco String
    $StringCleanSet = " "
    $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
    for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
        $StringCleanSet += " " 
    }

    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition

    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $RunSetup.Configuration.Forest.Installation -NoNewline -ForegroundColor Magenta

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # Reading key press
        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
        # Analyzong key pressed
        if ($key.VirtualKeyCode -eq 13) {
            # Is Last Choice or Yes if no previous choice
            if ($RunSetup.Configuration.Forest.Installation -eq '' -or $null -eq $RunSetup.Configuration.Forest.Installation) {
                # No previous choice, so it's a Yes
                Write-Host "Yes" -ForegroundColor Green
                $ForestChoice = "Yes"
            }
            Else {
                if ($RunSetup.Configuration.Forest.Installation -eq 'No') {
                    $color = 'Red'
                } 
                Else {
                    $color = 'Green'
                }
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $RunSetup.Configuration.Forest.Installation -ForegroundColor $color
                $ForestChoice = $RunSetup.Configuration.Forest.Installation
            }
            $isKO = $false
        }
        Elseif ($key.VirtualKeyCode -eq 89) {
            # Is Yes
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "Yes" -ForegroundColor Green
            $ForestChoice = "Yes"
            $isKO = $false
        }
        elseif ($key.VirtualKeyCode -eq 78) {
            # Is No
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "No" -ForegroundColor Red
            $ForestChoice = "No"
            $isKO = $false
        }
        Else {
            # Is "do it again"!
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
            $isKO = $true
        }
    }
    ### Writing result to XML
    $RunSetup.Configuration.Forest.Installation=$ForestChoice
    $DbgLog += @("Install a new forest: $ForestChoice")

    ## Getting Forest Data
    $RunSetup = Get-HmDForest $ForestChoice $RunSetup
    $DbgLog += @("Forest - FullName: $($RunSetup.Configuration.Forest.FullName)","Forest - NetBIOS: $($RunSetup.Configuration.Forest.NetBIOS)","Forest - FFL: $($RunSetup.Configuration.Forest.FunctionalLevel)")
    $DbgLog += @("Forest - RecycleBin: $($RunSetup.Configuration.Forest.RecycleBin)","Forest - PAM: $($RunSetup.Configuration.Forest.PAM)")

    ## Geting Domain Data
    $RunSetup = Get-HmDDomain $ForestChoice $RunSetup
    $DbgLog += @("Domain - Type: $($RunSetup.Configuration.Domain.Type)","Domain - FullName: $($RunSetup.Configuration.Domain.FullName)","Domain - NetBIOS: $($RunSetup.Configuration.Domain.NetBIOS)")
    $DbgLog += @("Domain - FFL: $($RunSetup.Configuration.Domain.FunctionalLevel)","Domain - Sysvol Path: $($RunSetup.Configuration.Domain.sysvolPath)","Domain - NTDS Path: $($RunSetup.Configuration.Domain.NtdsPath)")

    ## Checking for binaries...
    $binaries = $ScriptSettings.Settings.WindowsFeatures.Role

    foreach ($Binary in $binaries) {
        # Getting Install Status
        $InsStat = (Get-WindowsFeature $Binary.Name).InstallState

        # What will we do? 
        Switch ($InsStat) {
            # Available for installation
            "Available" {
                # Update xml
                $RunSetup.Configuration.WindowsFeatures.$($Binary.Name) = "Yes"
                $DbgLog += @("Install $($Binary.Name): Yes")
            }
            # Any other status may end in error...
            Default {
                # Update xml
                $RunSetup.Configuration.WindowsFeatures.$($Binary.Name) = "No"  
                $DbgLog += @("Install $($Binary.Name): No")
            }
        }
    }

    # Saving RunSetup.xml
    $RunSetup.save((Resolve-Path .\Configuration\RunSetup.xml).Path)
    $DbgLog += @(' ','File RunSetup.xml updated and saved.',' ')
    Write-toEventLog INFO $DbgLog | Out-Null
}
#endregion

#region USE CASE 2: SETUP AD
Elseif (-not($AddDC)) {
    # Checking if the domain is to be installed or not
    $isDomain = (gwmi win32_computersystem).partofdomain

    #region Use Case B: Is already a DC... Time for hardening
    if ($isDomain) {
        # Action result counters
        $isSuccess = 0
        $isWarning = 0
        $isFailure = 0

        #Region PingCastle Script Fixes
        # Fix list
        $PCFixList  = @('S-ADRegistration','S-DC-SubnetMissing','S-DC-SubnetMissing-IPv6','S-PwdNeverExpires','P-RecycleBin','P-SchemaAdmin')
        $PCFixList += @('P-UnprotectedOU','A-MinPwdLen','A-PreWin2000AuthenticatedUsers','A-LAPS-NOT-Installed','P-Delegated')
        # Fix loop
        foreach ($Resolution in $PCFixList) {
            # Get cursor position
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            # Display action
            Write-Host "[       ] Fixing PingCastle alert...: $Resolution"
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
            Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline
            # Calling the fix
            $fixResult = &"resolve-$($Resolution -replace '-','')"
            # Switching display based on returned value
            switch ($fixResult) {
                "Info" { 
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                    $isSuccess++
                }
                "Warning" {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[4] -ForegroundColor $arrayColrTxt[4]
                    $isWarning++
                }
                "Error" {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                    $isFailure++
                }
            }
        }
        #endregion

        #Region PurpleKnight Script Fixes
        # Fix list
        $PKFixList  = @('Protected-Users','LDAPS-required')
        # Fix loop
        foreach ($Resolution in $PKFixList) {
            # Get cursor position
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            # Display action
            Write-Host "[       ] Fixing PurpleKnight alert.: $Resolution"
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
            Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline
            # Calling the fix
            $fixResult = &"resolve-$($Resolution -replace '-','')"
            # Switching display based on returned value
            switch ($fixResult) {
                "Info" { 
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                    $isSuccess++
                }
                "Warning" {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[4] -ForegroundColor $arrayColrTxt[4]
                    $isWarning++
                }
                "Error" {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                    $isFailure++
                }
            }
        }
        #endregion

        #Region Import GPO
        $DomainSettings = Get-XmlContent .\Configuration\DomainSettings.xml

        foreach ($GPO in $DomainSettings.Settings.GroupPolicies.Gpo) {
            # Get cursor position
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            # Display action
            Write-Host "[       ] Adding Security GPO.......: $($GPO.Name)"
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
            Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline

            Try {
                $gpChek = Get-GPO -Name $GPO.Name -ErrorAction SilentlyContinue
                if ($gpChek) {
                    Write-ToEventLog -EventType WARNING -EventMsg "GPO $($GPO.Name): already imported."
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[4] -ForegroundColor $arrayColrTxt[4]
                    $isWarning++
                }
                Else {
                    $gpPath = (Get-AdDomain).DistinguishedName
                    if ($GPO.Linkage -eq "DC") {
                        $gpPath = "OU=Domain Controllers,$gpPath"
                    }
                    [void](New-Gpo -Name $gpo.Name -ErrorAction Stop)
                    [void](Import-GPO -BackupId $GPO.BackupId -TargetName $gpo.Name -Path $PSScriptRoot\Imports\$($GPO.Name) -ErrorAction Stop)
                    [void](New-GPLink -Name $gpo.Name -Target $gpPath -LinkEnabled Yes -Order 1 -ErrorAction Stop)
                    Write-ToEventLog -EventType INFO -EventMsg "GPO $($GPO.Name): imported successfully."
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                    $isSuccess++
                }
            }
            Catch {
                Write-ToEventLog -EventType Error -EventMsg "GPO $($GPO.Name): import failed! Error: $($_.ToString())"
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                $isFailure++                
            }
        }
        #endregion

        #region import delegation
        foreach ($Deleg in $DomainSettings.Settings.Delegations.Delegation) {
            # Get cursor position
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            # Display action
            Write-Host "[       ] Setting-up delegation.....: $($Deleg.Name)"
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
            Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline

            $fixResult = &"$($Deleg.Name)"
            # Switching display based on returned value
            switch ($fixResult) {
                "Info" { 
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                    $isSuccess++
                }
                "Warning" {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[4] -ForegroundColor $arrayColrTxt[4]
                    $isWarning++
                }
                "Error" {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                    $isFailure++
                }
            }
        }
        #endregion

        #region Result Array for final display
        $Results = New-Object -TypeName psobject -Property @{Success=$isSuccess ; Warning=$isWarning ; Error=$isFailure}
        $Results | Select-Object Success,Warning,Error | Format-Table -AutoSize

        # Final action: reboot
        $UserDeclined = Write-WarningText -Id FinalAction
        if ($UserDeclined) {
            Write-toEventLog -EventType Warning -EventMsg @("User has canceled the reboot.",'But I give no care, that is to be done.','...','Wait, he is my master...','Damned. No reboot...',' ',"END: invoke-HelloMyDir")
            Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
            Exit 0
        } Else {
            Restart-Computer -force | Out-Null
        }
        #endregion
    }
    #endregion

    #region Use Case A: The domain is to be installed...
    Else {
        $DbgLog += @('USE CASE: A - The domain is to be installed')
        
        # The script may require to install binairies. In any case, a reboot will be needed and the script run a second time.
        # A warning message is shown to the user with a reminder to run the script once logged in back.
        $UserDeclined = Write-WarningText -Id RebootAction
        if ($UserDeclined) {
            Write-toEventLog -EventType Warning -EventMsg @("User has canceled the installation.","END: invoke-HelloMyDir")
            Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
            Exit 0
        }

        # Loading user desiderata
        $RunSetup = Get-XmlContent .\Configuration\RunSetup.xml

        #region Dealing with binaries to install
        $reqBinaries = @('AD-Domain-Services','RSAT-AD-Tools','RSAT-DNS-Server','RSAT-DFS-Mgmt-Con','GPMC')
        $BinariesStatus = $RunSetup.Configuration.WindowsFeatures
        $prerequesiteKO = $false
        
        $ProgressPreference = "SilentlyContinue"

        foreach ($ReqBinary in $reqBinaries) {
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            Write-Host "[       ] binaries installation.....: $ReqBinary"
            if ($BinariesStatus.$ReqBinary -eq 'Yes') {
                # installing
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline

                Try {
                    install-windowsFeature -Name $ReqBinary -IncludeAllSubFeature -ErrorAction Stop | Out-Null
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                    $RunSetup.Configuration.WindowsFeatures.$ReqBinary = "No"
                }
                Catch {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]                     
                    $prerequesiteKO = $True
                }
            }
            Else {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[3] -ForegroundColor $arrayColrTxt[3]
            }
        }
        $RunSetup.Save((Resolve-Path .\Configuration\RunSetup.xml).Path)
        $ProgressPreference = "Continue"
        #endregion

        # Display data
        $CursorPosition = $Host.UI.RawUI.CursorPosition
        Write-Host "[       ] Installing your new domain $($RunSetup.Configuration.Domain.FullName)"

        # installing
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
        Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline

        # Snooze progress bar
        $ProgressPreference = "SilentlyContinue"

        # Start installation...
        Switch ($RunSetup.Configuration.Forest.Installation) {
            "Yes" {
                $randomSMpwd = New-RandomComplexPasword -Length 24 -AsClearText
                $HashArguments = @{
                    CreateDNSDelegation           = $false
                    DatabasePath                  = $RunSetup.Configuration.Domain.NtdsPath
                    DomainMode                    = $RunSetup.Configuration.Domain.FunctionalLevel
                    DomainName                    = $RunSetup.Configuration.Forest.FullName
                    ForestMode                    = $RunSetup.Configuration.Forest.FunctionalLevel
                    LogPath                       = "C:\Logs"
                    SysvolPath                    = $RunSetup.Configuration.Domain.SysvolPath
                    SafeModeAdministratorPassword = ConvertTo-SecureString -AsPlainText $randomSMpwd -Force
                    DomainNetbiosName             = ($RunSetup.Configuration.Domain.NetBIOS).ToUpper()
                    NoRebootOnCompletion          = $true
                    Confirm                       = $false
                    Force                         = $true
                    SkipPreChecks                 = $true
                    ErrorAction                   = "Stop"
                    WarningAction                 = "SilentlyContinue"
                    informationAction             = "SilentlyContinue"
                }
                Try {
                    Install-ADDSForest @HashArguments | Out-Null
                    
                    $DbgLog += "Installation completed. The server will now reboot."
                    Write-toEventLog INFO $DbgLog

                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1] 
                    Write-Host
                    Write-Host "IMPORTANT!" -ForegroundColor Black -BackgroundColor Red -NoNewline
                    Write-Host " Please write-down the DSRM password randomly generated: " -ForegroundColor Yellow -NoNewline
                    Write-Host "$randomSMpwd" -ForegroundColor White -BackgroundColor Green
                    Write-Host 
                    Write-Host "Press any key to let the server reboot once you're ready..." -ForegroundColor Yellow -NoNewline
                    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
                    Write-Host
                    $ProgressPreference = "Continue"
                    Restart-Computer -Force | out-null
                    Exit 0
                }
                Catch {
                    $DbgLog += @("Installation Failed!",($Error[0]).ToString())
                    $HashArgumentsDebug = @("Install-ADDSForest failed with the following arguments:",
                                            "CreateDNSDelegation = $false",
                                            "DatabasePath = $($RunSetup.Configuration.Domain.NtdsPath)",
                                            "DomainMode = $($RunSetup.Configuration.Domain.FunctionalLevel)",
                                            "DomainName = $($RunSetup.Configuration.Forest.FullName)",
                                            "ForestMode = $($RunSetup.Configuration.Forest.FunctionalLevel)",
                                            "LogPath = ""C:\Logs""",
                                            "SysvolPath = $($RunSetup.Configuration.Domain.SysvolPath)",
                                            "SafeModeAdministratorPassword = ConvertTo-SecureString -AsPlainText $randomSMpwd -Force",
                                            "DomainNetbiosName = $(($RunSetup.Configuration.Domain.NetBIOS).ToUpper())",
                                            "NoRebootOnCompletion = $true",
                                            "Confirm = $false",
                                            "Force = $true",
                                            "SkipPreChecks = $true",
                                            "ErrorAction = ""Stop""",
                                            "WarningAction = ""SilentlyContinue""",
                                            "informationAction = ""SilentlyContinue""",
                                            "progressAction = ""SilentlyContinue"""
                    )
                    Write-toEventLog Error $DbgLog
                    Write-toEventLog Warning $HashArgumentsDebug
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                    Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2] -NoNewline
                }
            }
            "No" {
            }
        }
    }
    #endregion
}
#endregion

#region USE CASE 3: ADD DC
Elseif ($AddDC) {
    # Prepare debug log
    $DbgLog = @('PHASE EXTEND: ADD A DC.',' ')

    #region Get Computer info
    $CursorPosition = $Host.UI.RawUI.CursorPosition
    Write-Host "[       ] Getting Computer informations"
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
    Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline
    Try {
        $ProgressPreference = "SilentlyContinue"
        $CsComputer = Get-ComputerInfo
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
        Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
    }
    Catch {
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
        Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
        $DbgLog += "Failed to get computer informations! Error: $($_.ToString())"
        $prerequesiteKO = $True
    }
    #endregion

    # If this is a domain member or standalone server, then we can install.
    # DomainRole acceptable value: https://learn.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.domainrole?view=powershellsdk-7.4.0
    if ($CsComputer.CsDomainRole -eq 2 -or $CsComputer.CsDomainRole -eq 3) {
        #region Install Prerequesites
        $DbgLog += "The system is in an expected state (CsCDomainRole: $($CsComputer.CsDomainRole))"
        # Check if prerequesite are installed.
        # Loading user desiderata
        $RunSetup = Get-XmlContent .\Configuration\RunSetup.xml
        
        #region Dealing with binaries to install
        $reqBinaries = @('AD-Domain-Services','RSAT-AD-Tools','RSAT-DNS-Server','RSAT-DFS-Mgmt-Con','GPMC')

        $ProgressPreference = "SilentlyContinue"
        foreach ($ReqBinary in $reqBinaries) {
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            Write-Host "[       ] binaries installation.....: $ReqBinary"
            # installing
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
            Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline

            Try {
                install-windowsFeature -Name $ReqBinary -IncludeAllSubFeature -ErrorAction Stop | Out-Null
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                $DbgLog += "$($ReqBinary): installed sucessfully."
            }
            Catch {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                $DbgLog += "$($ReqBinary): Failed to install! Error: $($_.ToString())"
                $prerequesiteKO = $True
            }
        }
        $ProgressPreference = "Continue"
        #endregion
        #endregion

        $DJoinUsr = $RunSetup.Configuration.ADObjects.Users.DomainJoin
        $DomainFN = $RunSetup.Configuration.domain.FullName
        $DomainNB = $RunSetup.Configuration.domain.NetBIOS
        #region is not domain member
        $CursorPosition = $Host.UI.RawUI.CursorPosition
        Write-Host "[       ] Promoting the server as a domain member"
        if ($CsComputer.CsDomainRole -eq 2) {
            $DbgLog += @(" ","The server is not a domain member: the server will be joined to the domain first.")
            try {
                [void](Add-Computer -DomainName $DomainFN -Credential (Get-Credential -Message 'Enter credential to join this computer to the domain' -User "$DomainNB\$DJoinUsr"))
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                $DbgLog += @(" ","The server will reboot - rerun the script to make it a domain controller.")

                Write-Host
                Write-Host "IMPORTANT!" -ForegroundColor Black -BackgroundColor Red
                Write-Host "The server have to reboot to finalize the domain joining process." -ForegroundColor White
                Write-Host "Rerun the script to make it a DC." -ForegroundColor Yellow
                Write-Host 
                Write-Host "Press any key to let the server reboot once you're ready..." -ForegroundColor DarkGray -NoNewline
                $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
                Write-Host
                $ProgressPreference = "Continue"
                Write-toEventLog Info $DbgLog
                Restart-Computer -Force | out-null
                Exit 0
            }
            Catch {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                $DbgLog += @("Error! The server failed to join the domain!",' ',"Error: $($_.ToString())")
                Write-Host "`nError! Failed to join the domain!`nError: $($_.ToString())`n" -ForegroundColor Red
                Write-toEventLog Error $DbgLog
                Exit 4
            }
        }
        Else {
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
            Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
            $DbgLog += @(" ","The server is a domain member (prerequesite to domain join with a protected users account)")
        }
        #endregion

        #region add DC
        if (-not($prerequesiteKO)) {
            #region reset ACL and owner
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            Write-Host "[       ] Reseting owner and SDDL for security purpose"
            $NoError = $True
            Try {
                $DAsid  = [String](Get-ADDomain $DomainFN).DomainSID.Value + "-512"
                $DAName = (Get-ADGroup $DAsid -Server $DomainFN).Name
                $Cptr   = Get-ADComputer $env:computername -Properties nTSecurityDescriptor -Credential $Creds
                $Cptr | foreach {
                    $DistinguishedName    = $_.DistinguishedName
                    $GroupCategory        = $_.GroupCategory
                    $GroupScope           = $_.GroupScope
                    $Name                 = $_.Name
                    $ObjectClass          = $_.ObjectClass
                    $ObjectGUID           = $_.ObjectGUID
                    $SamAccountName       = $_.SamAccountName
                    $SID                  = $_.SID
                    $nTSecurityDescriptor = $_.nTSecurityDescriptor
                
                    $Array = New-Object psobject -Property @{
                        DistinguishedName = $DistinguishedName
                        DNSHostName       = $DNSHostName
                        Enabled           = $Enabled
                        Name              = $Name
                        ObjectClass       = $ObjectClass
                        ObjectGUID        = $ObjectGUID
                        SamAccountName    = $SamAccountName
                        SID               = $SID
                        Owner             = $nTSecurityDescriptor.owner
                        }
                }
            }
            Catch {
                $NoError = $False
                $DbgLog += @(' ',"Could not get computer data to reset owner/sddl!","Error:$($_.ToString())")
            }
            Try {
                $Array | foreach {
                # Current  Computer
                $SamAccountName = $_.SamAccountName
                # Change Owner
                ## Define Target
                $TargetObject = Get-ADComputer $SamAccountName -Server $DomainFN
                $AdsiTarget = [adsi]"LDAP://$DomainFN/$($TargetObject.DistinguishedName)"
                ## Set new Owner
                $NewOwner = New-Object System.Security.Principal.NTAccount($DAName)
                $AdsiTarget.PSBase.ObjectSecurity.SetOwner($NewOwner)
                $AdsiTarget.PSBase.CommitChanges()
                }
            }
            Catch {
                $NoError = $False
                $DbgLog += @(' ',"Could not reset owner!","Error:$($_.ToString())")
            }
            # Sleep
            Start-Sleep -Seconds 10
            # Reset ACL
            Try {
                ## Get computer default ACL
                $SchemaNamingContext = (Get-ADRootDSE -Server $DomainFN).schemaNamingContext
                $DefaultSecurityDescriptor = Get-ADObject -Identity "CN=Computer,$SchemaNamingContext" -Properties defaultSecurityDescriptor | Select-Object -ExpandProperty defaultSecurityDescriptor

                $ADObj = Get-ADComputer -Identity $SamAccountName -Properties nTSecurityDescriptor -ErrorAction Stop

                $ADObj.nTSecurityDescriptor.SetSecurityDescriptorSddlForm( $DefaultSecurityDescriptor )
                Set-ADObject -Identity $ADObj.DistinguishedName -Replace @{ nTSecurityDescriptor = $ADObj.nTSecurityDescriptor } -Confirm:$false 
            }
            Catch {
                $NoError = $False
                $DbgLog += @(' ',"Could not reset SDDL!","Error:$($_.ToString())")
            }
            if ($NoError) {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                $DbgLog += @(" ","The computer object is now safe and secure.")
            }
            Else {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                $DbgLog += @(" ","The computer object has a wrong owner and/or SDDL are unsafe!")
            }
            #endregion

            #region deploy ADDS
            # Display data
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            Write-Host "[       ] Installing your new domain controller in $($DomainFN.ToUpper())"

            # installing
            $BuiltinAdmin = (Get-AdUSer "$((Get-AdDomain).DomainSID.Value)-500").SamAccountName
            $Creds = Get-Credential -Message 'Enter Domain Admins accounts' -User "$DomainNB\$BuiltinAdmin"
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
            Write-Host $arrayRsltTxt[0] -ForegroundColor $arrayColrTxt[0] -NoNewline

            # Snooze progress bar
            $ProgressPreference = "SilentlyContinue"

            # Start installation...
            $randomSMpwd = New-RandomComplexPasword -Length 24 -AsClearText
            $HashArguments = @{
                Credential                    = $Creds
                DatabasePath                  = $RunSetup.Configuration.Domain.NtdsPath
                DomainName                    = $RunSetup.Configuration.domain.FullName
                SysvolPath                    = $RunSetup.Configuration.Domain.SysvolPath
                SafeModeAdministratorPassword = ConvertTo-SecureString -AsPlainText $randomSMpwd -Force
                NoRebootOnCompletion          = $true
                Confirm                       = $false
                Force                         = $true
                SkipPreChecks                 = $true
                ErrorAction                   = "Stop"
                WarningAction                 = "SilentlyContinue"
                informationAction             = "SilentlyContinue"
            }
            Try {
                Install-ADDSDomainController @HashArguments | Out-Null
                
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1] 
            }
            Catch {
                $DbgLog += @("Installation Failed!","Error: $($_.ToString())")
                $DbgLog += @("Install-ADDSDomainController failed with the following arguments:",
                             "Credential = (cyphered data)",
                             "DatabasePath = $($RunSetup.Configuration.Domain.NtdsPath)",
                             "DomainName = $($RunSetup.Configuration.Forest.FullName)",
                             "SysvolPath = $($RunSetup.Configuration.Domain.SysvolPath)",
                             "SafeModeAdministratorPassword = ConvertTo-SecureString -AsPlainText $randomSMpwd -Force",
                             "NoRebootOnCompletion = $true",
                             "Confirm = $false",
                             "Force = $true",
                             "SkipPreChecks = $true",
                             "ErrorAction = ""Stop""",
                             "WarningAction = ""SilentlyContinue""",
                             "informationAction = ""SilentlyContinue""",
                             "progressAction = ""SilentlyContinue"""
                            )
                Write-toEventLog Error $DbgLog
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
            }
            #endregion

            #region setup for ldaps
            $CursorPosition = $Host.UI.RawUI.CursorPosition
            Write-Host "[       ] Setup certificate for LDAPS"
            $DbgLog += @(' ','Installing a certificate for ldaps...')
            Try {
                # Calling the fix
                $fixResult = &"resolve-LDAPSrequired"
                # Switching display based on returned value
                switch ($fixResult) {
                    "Info" { 
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                        Write-Host $arrayRsltTxt[1] -ForegroundColor $arrayColrTxt[1]
                        $DbgLog += 'Certificate installed.'
                    }
                    "Warning" {
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                        Write-Host $arrayRsltTxt[4] -ForegroundColor $arrayColrTxt[4]
                        $DbgLog += 'WARNING: seems that the certificate was not copied in the root store.'
                    }
                    "Error" {
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                        Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                        $DbgLog += 'ERROR: failed to create the certificate!'
                    }
                }
            }
            Catch {
                $DbgLog += @("Failed to create a self signed certificate!","Error:$($_.ToString())")
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates ($CursorPosition.X +1), $CursorPosition.Y 
                Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
            }
            #endregion

            #region Final Reboot
            $DbgLog += "Installation completed. The server will now reboot."
            Write-toEventLog $fixResult $DbgLog

            Write-Host
            Write-Host "IMPORTANT!" -ForegroundColor Black -BackgroundColor Red -NoNewline
            Write-Host " Please write-down the DSRM password randomly generated: " -ForegroundColor Yellow -NoNewline
            Write-Host "$randomSMpwd" -ForegroundColor Green
            Write-Host 
            Write-Host "Press any key to let the server reboot once you're ready..." -ForegroundColor Yellow -NoNewline
            $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
            Write-Host
            $ProgressPreference = "Continue"
            Restart-Computer -Force | out-null
            Exit 0
            #endregion
        }
        Else {
            # One or more Prerequesite have failed, hence this is to be reviewed. the script halt.
            Write-Host "`tOne or more Prerequesite have failed, hence this is to be reviewed. the script halt.`t" -Foregroundcolor Red
            $DbgLog += "One  One or more Prerequesite have failed, hence this is to be reviewed. the script halt."
            Write-toEventLog -EventType ERROR -EventMsg $DbgLog
            Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
            Exit 2
        }
        #endregion
    }
    Else {
        $DbgLog += @("Error! The system is not in an expected state! Error: CsDomainMode is $($CsComputer.CsDomainMode) ; Allowed value are 2 and 3.","More information here: https://learn.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.domainrole?view=powershellsdk-7.4.0")
    }
}
#endregion

# Exit
Write-toEventLog -EventType INFO -EventMsg "END: invoke-HelloMyDir"
Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
Exit 0
