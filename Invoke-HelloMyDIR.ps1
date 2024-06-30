<#
    .SYNOPSIS
    This is the main script of the project "Hello my Dir!".

    .COMPONENT
    PowerShell v5 minimum.

    .DESCRIPTION
    This is the main script to execute the project "Hello my Dir!". This project is intended to ease in building a secure active directory from scratch and maintain it afteward.

    .PARAMETER UpdateConfigFile
    Instruct the script to check and, if needed, update the configuration file (RunSetup.xml) when the script runs a new edition.

    .PARAMETER Prepare
    Instruct the script to create or edit the setup configuration file (RunSetup.xml).

    .PARAMETER AddDC
    Instruct the script to add a new DC to your domain.

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
    .\Invoke-HelloMyDir.ps1 -UpdateConfigFile
    Will run the script and update the file RunSetup.xml, if exists (else, does nothing).

    .NOTES
    Version.: 01.01.000
    Author..: Loic VEIRMAN (MSSec)
    History.: 
    01.00.000   Script creation.
    01.01.000   Hello my DC - Add a DC to your forest.

    Exit Code:
    1...: Prerequesite are not compliant.
    2...: Failed to add the server to the domain.
    3...: Not logged in with a domain account.
    4...: Not using a domain or enterprise admins account.
    998.: AD Query failed abnormaly. Emmergency exit.
    999.: PowerShell Major version is not compliant (5.x expected).
#>

#Region help, params and init
[CmdletBinding(DefaultParameterSetName = 'NewForest')]
Param
(
    [Parameter(Position = 0, ParameterSetName = 'NewForest')]
    [switch]
    $Prepare,

    [Parameter(Position = 1, ParameterSetName = 'NewDC')]
    [switch]
    $AddDC,

    [Parameter(Position = 2, ParameterSetName = 'Update')]
    [Switch]
    $UpdateConfigFile
)

# Script requirement
#Requires -RunAsAdministrator
#Requires -Version 5.0

# Common variables for this script:
# > ScriptPrerequesite: True at init. Set to false if one of the prerequesite fails (loading modules, reading configuration files, ...)
# > ScriptEdition.....: Contains the HmD current edition. Used to check if an existing RunSetup.xml is in the expected format.
# > arrayScriptLog....: Data to be added to the Event Log of the system for troubleshooting.
# > xmlDomainSettings.: xml data from DomainSettings.xml. Null on loading, filled-up with the function Get-XmlContent.
# > xmlScriptSettings.: xml data from ScriptSettings.xml. Null on loading, filled-up with the function Get-XmlContent.
# > xmlRunSetup.......: xml data from RunSetup.xml. Null on loading, filled-up with the function Get-XmlContent.

$ScriptPrerequesite = $True
$ScriptEdition      = '1.1.0'
$arrayScriptLog     = @("Running Hello My DIR! Edition $ScriptEdition.")
$xmlDomainSettings  = $null
$xmlScriptSettings  = $null
$xmlRunSetup        = $null

# Ensure running in PShell 5.x
if ($PSVersionTable.PSVersion.Major -ne 5)
{
    Write-Host "You must run this script using PowerShell Major Version 5!`n" -ForegroundColor Red
    Exit 999
}

# Load modules
Try 
{
    Import-module -Name (Get-ChildItem .\Modules).FullName -ErrorAction Stop -WarningAction SilentlyContinue 
}
Catch 
{
    Write-host "Failed to load one or modules!" -ForegroundColor Red
    Write-Host  "`nError message...: $($_.ToString())`n" -ForegroundColor Yellow
    $ScriptPrerequesite = $false
}

# Create Event Log Source and Event (need module-Logs)
try 
{
    Switch(Test-EventLog -ErrorAction Stop -WarningAction SilentlyContinue)
    {
        $False
        {
            Write-Host "Failed to create the Event Log!" -ForegroundColor Red
            Write-Host  "`nError message...: Function Test-EventLog returned 'False'.`n" -ForegroundColor Yellow
            $ScriptPrerequesite = $false
        }
        Default
        {
            $arrayScriptLog += @(' ','Event Log "HelloMyDir" successfully created in "Applications and Services Logs"')
        }
    }
}
catch 
{
    Write-Host "Failed to create the Event Log!" -ForegroundColor Red
    Write-Host  "`nError message...: $($_.ToString())`n" -ForegroundColor Yellow
    $ScriptPrerequesite = $false    
}

# Loading XML data
try 
{
    $xmlDomainSettings  = Get-XmlContent -XmlFile .\Configuration\DomainSettings.xml
    $xmlScriptSettings  = Get-XmlContent -XmlFile .\Configuration\ScriptSettings.xml
    $xmlRunSetup        = Get-XmlContent -XmlFile .\Configuration\RunSetup.xml    
}
catch 
{
    Write-Host "Failed to create the Event Log!" -ForegroundColor Red
    Write-Host  "`nError message: $($_.ToString())`n" -ForegroundColor Yellow
    $ScriptPrerequesite = $false        
}

# Ensure that xml file are present and in the expected edition.
if ($xmlDomainSettings.Settings.Edition -ne $ScriptEdition -or $null -eq $xmlDomainSettings) 
{ 
    Write-Host "`nDomainSettings.xml is not in the expected format!" -ForegroundColor Red
    Write-Host  "Error message...: DomainSettings.xml version '$($xmlDomainSettings.Settings.Edition)' detected, instead of '$ScriptEdition'" -ForegroundColor Yellow
    Write-Host  "Advised solution: replace the DomainSettings.xml file with the proper one (downloadable from GitHub).`n"-ForegroundColor Yellow
    $ScriptPrerequesite = $false        
}
if ($xmlScriptSettings.Settings.Edition -ne $ScriptEdition -or $null -eq $xmlScriptSettings) 
{ 
    Write-Host "`nScriptSettings.xml is not in the expected format!" -ForegroundColor Red
    Write-Host  "Error message...: ScriptSettings.xml version '$($xmlScriptSettings.Settings.Edition)' detected, instead of '$ScriptEdition'" -ForegroundColor Yellow
    Write-Host  "Advised solution: replace the ScriptSettings.xml file with the proper one (downloadable from GitHub).`n"-ForegroundColor Yellow
    $ScriptPrerequesite = $false        
}
if ($xmlRunSetup.Configuration.Edition -ne $ScriptEdition -and $null -ne $xmlRunSetup -and -not($UpdateConfigFile)) 
{ 
    Write-Host "`nRunSetup.xml is not in the expected format!" -ForegroundColor Red
    Write-Host  "Error message...: RunSetup.xml version '$($xmlRunSetup.Configuration.Edition)' detected, instead of '$ScriptEdition'" -ForegroundColor Yellow
    Write-Host  "Advised solution: run the script with the parameter '-UpdateConfigFile'.`n"-ForegroundColor Yellow
    $ScriptPrerequesite = $false        
}
elseif ($null -eq $xmlRunSetup)
{
    # Special use case: file is missing, we will instruct the script to create it first.
    $Prepare = $true
}
if ($ScriptPrerequesite)
{
    $arrayScriptLog += @(' ','All prerequesites are fullfilled. Parameters for this run:',"> Prepare: $Prepare","> UpdateConfigFile: $UpdateConfigFile","> AddDC: $AddDC")
}
else 
{
    Write-Host "The script can not continue." -ForegroundColor Red
    [void](Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue)
    Exit 1
}
#endregion

#region run script
#region Say Hello
# Write Header
Clear-Host
$ScriptTitle = @(' ',"$([Char]0x2554)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2557)" `
                    ,"$([Char]0x2551) Hello My DIR! $([Char]0x2551)" `
                    ,"$([Char]0x2551) version 1.1.0 $([Char]0x2551)" `
                    ,"$([Char]0x2551) Lic. GNU GPL3 $([Char]0x2551)" `
                    ,"$([Char]0x255A)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x255D)" `
                    ,' ')
Write-TitleText -Text $ScriptTitle

# Say Hello: Display welcome text
$toDisplayXml = Select-Xml $xmlScriptSettings -XPath "//Text[@ID='000']" | Select-Object -ExpandProperty Node
$toDisplayArr = @($toDisplayXml.Line1)
if ($toDisplayXml.Line2) { $toDisplayArr += @($toDisplayXml.Line2) }
if ($toDisplayXml.Line3) { $toDisplayArr += @($toDisplayXml.Line3) }
if ($toDisplayXml.Line4) { $toDisplayArr += @($toDisplayXml.Line4) }
Write-InformationalText -Text $toDisplayArr
Write-Host

# Compute Script Execution mode
if ($UpdateConfigFile) { $ScriptMode = "Update"            }
elseif ($Prepare)      { $ScriptMode = "First Run"         }
elseif ($AddDC)        { $ScriptMode = "Add new DC"        }
Else                   { $ScriptMode = "Create new Domain" }

# Logging to Event log
$arrayScriptLog += @(' ',"Script will now call mode: $ScriptMode.")
Write-toEventLog INFO $arrayScriptLog
$arrayScriptLog = $null
#endregion
# Calling script mode
Switch ($ScriptMode)
{
    #region update
    "Update"
    {
        $arrayScriptLog = @('EXECUTION MODE: UPDATE')
        # information start
        $relativeCoordinate = Write-Progression -Step Create -Message "Update RunSetup.xml to edition $ScriptEdition"
        write-Progression -Step Update -Code Running -CursorPosition $relativeCoordinate
        write-host 
        # Calling function to update
        $updateResult = Update-HmDRunSetupXml
        $arrayScriptLog += @(' ',$updateResult.Message)

        # information update
        write-Progression -Step Update -Code $updateResult.Code -CursorPosition $relativeCoordinate

        # Asking user to confirm xml data if it is a success
        if ($updateResult.Code -eq "success")
        {
            $arrayScriptLog += @(' ',"Validating new data:")
            
            # Loading xml
            $xmlRunSetup = Get-XmlContent .\Configuration\RunSetup.xml -ErrorAction SilentlyContinue

            # Is it a new forest?
            # Calling Lurch from Adam's family...
            $LurchMood = @(($xmlScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

            # Display question 
            $toDisplayXml = Select-Xml $xmlScriptSettings -XPath "//Text[@ID='001']" | Select-Object -ExpandProperty Node
            $toDisplayArr = @($toDisplayXml.Line1)
            $toDisplayArr += $toDisplayXml.Line2
            Write-UserChoice $toDisplayArr
            
            # Yes/No time
            # Get current cursor position and create the Blanco String
            $StringCleanSet = " "
            $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
            for ($i=2 ; $i -le $MaxStringLength ; $i++) 
            { 
                $StringCleanSet += " " 
            }

            # Getting cursor position for relocation
            $CursorPosition = $Host.UI.RawUI.CursorPosition

            # Writing default previous choice (will be used if RETURN is pressed)
            Write-Host $xmlRunSetup.Configuration.Forest.Installation -NoNewline -ForegroundColor Magenta

            # Querying input: waiting for Y,N or ENTER.
            $isKO = $True
            While ($isKO)
            {
                # Reading key press
                $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
                # Analyzong key pressed
                if ($key.VirtualKeyCode -eq 13) 
                {
                    # Is Last Choice or Yes if no previous choice
                    if ($xmlRunSetup.Configuration.Forest.Installation -eq '' -or $null -eq $xmlRunSetup.Configuration.Forest.Installation) 
                    {
                        # No previous choice, so it's a Yes
                        Write-Host "Yes" -ForegroundColor Green
                        $ForestChoice = "Yes"
                    }
                    Else 
                    {
                        if ($xmlRunSetup.Configuration.Forest.Installation -eq 'No') 
                        {
                            $color = 'Red'
                        } 
                        Else
                        {
                            $color = 'Green'
                        }
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                        Write-Host $xmlRunSetup.Configuration.Forest.Installation -ForegroundColor $color
                        $ForestChoice = $xmlRunSetup.Configuration.Forest.Installation
                    }
                    $isKO = $false
                }
                Elseif ($key.VirtualKeyCode -eq 89) 
                {
                    # Is Yes
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host "Yes" -ForegroundColor Green
                    $ForestChoice = "Yes"
                    $isKO = $false
                }
                elseif ($key.VirtualKeyCode -eq 78) 
                {
                    # Is No
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host "No" -ForegroundColor Red
                    $ForestChoice = "No"
                    $isKO = $false
                }
                Else 
                {
                    # Is "do it again"!
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
                    $isKO = $true
                }
            }

            # Writing result to XML
            $xmlRunSetup.Configuration.Forest.Installation=$ForestChoice
            $arrayScriptLog += @("Install a new forest: $ForestChoice")

            # Getting Forest Data
            $xmlRunSetup = Get-HmDForest $ForestChoice $xmlRunSetup
            $arrayScriptLog += @("Forest - FullName: $($xmlRunSetup.Configuration.Forest.FullName)","Forest - NetBIOS: $($xmlRunSetup.Configuration.Forest.NetBIOS)","Forest - FFL: $($xmlRunSetup.Configuration.Forest.FunctionalLevel)")
            $arrayScriptLog += @("Forest - RecycleBin: $($xmlRunSetup.Configuration.Forest.RecycleBin)","Forest - PAM: $($xmlRunSetup.Configuration.Forest.PAM)")

            # Geting Domain Data
            $xmlRunSetup = Get-HmDDomain $ForestChoice $xmlRunSetup
            $arrayScriptLog += @("Domain - Type: $($xmlRunSetup.Configuration.Domain.Type)","Domain - FullName: $($xmlRunSetup.Configuration.Domain.FullName)","Domain - NetBIOS: $($xmlRunSetup.Configuration.Domain.NetBIOS)")
            $arrayScriptLog += @("Domain - FFL: $($xmlRunSetup.Configuration.Domain.FunctionalLevel)","Domain - Sysvol Path: $($xmlRunSetup.Configuration.Domain.sysvolPath)","Domain - NTDS Path: $($xmlRunSetup.Configuration.Domain.NtdsPath)")

            # Checking for binaries...
            $binaries = $xmlScriptSettings.Settings.WindowsFeatures.Role

            foreach ($Binary in $binaries) 
            {
                # Getting Install Status
                $InsStat = (Get-WindowsFeature $Binary.Name).InstallState

                # What will we do? 
                Switch ($InsStat) 
                {
                    # Available for installation
                    "Available" 
                    {
                        # Update xml
                        $xmlRunSetup.Configuration.WindowsFeatures.$($Binary.Name) = "Yes"
                        $arrayScriptLog += @("Install $($Binary.Name): Yes")
                    }
                    # Any other status may end in error...
                    Default 
                    {
                        # Update xml
                        $xmlRunSetup.Configuration.WindowsFeatures.$($Binary.Name) = "No"  
                        $arrayScriptLog += @("Install $($Binary.Name): No")
                    }
                }
            }

            # Saving RunSetup.xml
            $xmlRunSetup.save((Resolve-Path .\Configuration\RunSetup.xml).Path)
            $arrayScriptLog += @(' ','File RunSetup.xml updated and saved.',' ')
            [void](Write-toEventLog INFO $arrayScriptLog)
        }
        else 
        {
            $arrayScriptLog += @(' ','Could not confirm with user new parameters!')
            Write-ToEventLog Error $arrayScriptLog
        }
        Write-Host
    }
    #endregion
    #region first run
    "First Run"
    {
        $arrayScriptLog = @('EXECUTION MODE: FIRST RUN')
        $arrayScriptLog += @(' ',"asking for data:")
            
        # Creating empty file
        New-HmDRunSetupXml

        # Loading xml
        $xmlRunSetup = Get-XmlContent .\Configuration\RunSetup.xml -ErrorAction SilentlyContinue

        # Is it a new forest?
        # Calling Lurch from Adam's family...
        $LurchMood = @(($xmlScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

        # Display question 
        $toDisplayXml = Select-Xml $xmlScriptSettings -XPath "//Text[@ID='001']" | Select-Object -ExpandProperty Node
        $toDisplayArr = @($toDisplayXml.Line1)
        $toDisplayArr += $toDisplayXml.Line2
        Write-UserChoice $toDisplayArr
        
        # Yes/No time
        # Get current cursor position and create the Blanco String
        $StringCleanSet = " "
        $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
        for ($i=2 ; $i -le $MaxStringLength ; $i++) 
        { 
            $StringCleanSet += " " 
        }

        # Getting cursor position for relocation
        $CursorPosition = $Host.UI.RawUI.CursorPosition

        # Writing default previous choice (will be used if RETURN is pressed)
        Write-Host $xmlRunSetup.Configuration.Forest.Installation -NoNewline -ForegroundColor Magenta

        # Querying input: waiting for Y,N or ENTER.
        $isKO = $True
        While ($isKO)
        {
            # Reading key press
            $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
            # Analyzong key pressed
            if ($key.VirtualKeyCode -eq 13) 
            {
                # Is Last Choice or Yes if no previous choice
                if ($xmlRunSetup.Configuration.Forest.Installation -eq '' -or $null -eq $xmlRunSetup.Configuration.Forest.Installation) 
                {
                    # No previous choice, so it's a Yes
                    Write-Host "Yes" -ForegroundColor Green
                    $ForestChoice = "Yes"
                }
                Else 
                {
                    if ($xmlRunSetup.Configuration.Forest.Installation -eq 'No') 
                    {
                        $color = 'Red'
                    } 
                    Else
                    {
                        $color = 'Green'
                    }
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $xmlRunSetup.Configuration.Forest.Installation -ForegroundColor $color
                    $ForestChoice = $xmlRunSetup.Configuration.Forest.Installation
                }
                $isKO = $false
            }
            Elseif ($key.VirtualKeyCode -eq 89) 
            {
                # Is Yes
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host "Yes" -ForegroundColor Green
                $ForestChoice = "Yes"
                $isKO = $false
            }
            elseif ($key.VirtualKeyCode -eq 78) 
            {
                # Is No
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host "No" -ForegroundColor Red
                $ForestChoice = "No"
                $isKO = $false
            }
            Else 
            {
                # Is "do it again"!
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
                $isKO = $true
            }
        }

        # Writing result to XML
        $xmlRunSetup.Configuration.Forest.Installation=$ForestChoice
        $arrayScriptLog += @("Install a new forest: $ForestChoice")

        # Getting Forest Data
        $xmlRunSetup = Get-HmDForest $ForestChoice $xmlRunSetup
        $arrayScriptLog += @("Forest - FullName: $($xmlRunSetup.Configuration.Forest.FullName)","Forest - NetBIOS: $($xmlRunSetup.Configuration.Forest.NetBIOS)","Forest - FFL: $($xmlRunSetup.Configuration.Forest.FunctionalLevel)")
        $arrayScriptLog += @("Forest - RecycleBin: $($xmlRunSetup.Configuration.Forest.RecycleBin)","Forest - PAM: $($xmlRunSetup.Configuration.Forest.PAM)")

        # Geting Domain Data
        $xmlRunSetup = Get-HmDDomain $ForestChoice $xmlRunSetup
        $arrayScriptLog += @("Domain - Type: $($xmlRunSetup.Configuration.Domain.Type)","Domain - FullName: $($xmlRunSetup.Configuration.Domain.FullName)","Domain - NetBIOS: $($xmlRunSetup.Configuration.Domain.NetBIOS)")
        $arrayScriptLog += @("Domain - FFL: $($xmlRunSetup.Configuration.Domain.FunctionalLevel)","Domain - Sysvol Path: $($xmlRunSetup.Configuration.Domain.sysvolPath)","Domain - NTDS Path: $($xmlRunSetup.Configuration.Domain.NtdsPath)")

        # Checking for binaries...
        $binaries = $xmlScriptSettings.Settings.WindowsFeatures.Role

        foreach ($Binary in $binaries) 
        {
            # Getting Install Status
            $InsStat = (Get-WindowsFeature $Binary.Name).InstallState

            # What will we do? 
            Switch ($InsStat) 
            {
                # Available for installation
                "Available" 
                {
                    # Update xml
                    $xmlRunSetup.Configuration.WindowsFeatures.$($Binary.Name) = "Yes"
                    $arrayScriptLog += @("Install $($Binary.Name): Yes")
                }
                # Any other status may end in error...
                Default 
                {
                    # Update xml
                    $xmlRunSetup.Configuration.WindowsFeatures.$($Binary.Name) = "No"  
                    $arrayScriptLog += @("Install $($Binary.Name): No")
                }
            }
        }

        # Saving RunSetup.xml
        $xmlRunSetup.save((Resolve-Path .\Configuration\RunSetup.xml).Path)
        $arrayScriptLog += @(' ','File RunSetup.xml updated and saved.',' ')
        [void](Write-toEventLog INFO $arrayScriptLog)
        write-host
    }
    #endregion
    #region new domain
    "Create new Domain"
    {
        # Checking if the domain is to be installed or not
        $isDomain = (gwmi win32_computersystem).partofdomain

        # Switching following result
        Switch ($isDomain)
        {
            #region Not a domain member.
            $false
            {
                $arrayScriptLog += @('USE CASE: The domain is to be installed')
        
                # The script may require to install binairies. In any case, a reboot will be needed and the script run a second time.
                # A warning message is shown to the user with a reminder to run the script once logged in back.
                $UserDeclined = Write-WarningText -Id RebootAction
                if ($UserDeclined) 
                {
                    Write-toEventLog -EventType Warning -EventMsg @("User has canceled the installation.","END: invoke-HelloMyDir")
                    Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
                    Exit 0
                }
        
                # Loading user desiderata
                $xmlRunSetup = Get-XmlContent .\Configuration\RunSetup.xml
        
                #Dealing with binaries to install
                $reqBinaries = @('AD-Domain-Services','RSAT-AD-Tools','RSAT-DNS-Server','RSAT-DFS-Mgmt-Con','GPMC')
                $BinariesStatus = $xmlRunSetup.Configuration.WindowsFeatures
                $prerequesiteKO = $false
                
                $ProgressPreference = "SilentlyContinue"
        
                foreach ($ReqBinary in $reqBinaries) 
                {
                    $CursorPosition = Write-Progression -Step Create -message "binaries installation.....: $ReqBinary"
                    if ($BinariesStatus.$ReqBinary -eq 'Yes') 
                    {
                        # installing
                        Write-Progression -Step Update -code Running -CursorPosition $CursorPosition

                        Try 
                        {
                            install-windowsFeature -Name $ReqBinary -IncludeAllSubFeature -ErrorAction Stop | Out-Null
                            Write-Progression -Step Update success $CursorPosition
                            $xmlRunSetup.Configuration.WindowsFeatures.$ReqBinary = "No"
                        }
                        Catch 
                        {
                            Write-Progression -Step Update error $CursorPosition
                            $arrayScriptLog += @(' ',"Error: $($_.string())")
                            $prerequesiteKO = $True
                        }
                    }
                    Else 
                    {
                        Write-Progression -Step Update success $CursorPosition
                    }
                }
                $xmlRunSetup.Save((Resolve-Path .\Configuration\RunSetup.xml).Path)
                $ProgressPreference = "Continue"
        
                # Display data
                $CursorPosition = Write-Progression -Step Create -message "Installing your new domain $($xmlRunSetup.Configuration.Domain.FullName)"
                Write-Progression -Step Update -code Running -CursorPosition $CursorPosition
        
                # Snooze progress bar
                $ProgressPreference = "SilentlyContinue"
        
                # Start installation...
                if ($xmlRunSetup.Configuration.Forest.Installation -eq "Yes") 
                {
                    $randomSMpwd = New-RandomComplexPasword -Length 24 -AsClearText
                    $HashArguments = @{
                        CreateDNSDelegation           = $false
                        DatabasePath                  = $xmlRunSetup.Configuration.Domain.NtdsPath
                        DomainMode                    = $xmlRunSetup.Configuration.Domain.FunctionalLevel
                        DomainName                    = $xmlRunSetup.Configuration.Forest.FullName
                        ForestMode                    = $xmlRunSetup.Configuration.Forest.FunctionalLevel
                        LogPath                       = "C:\Logs"
                        SysvolPath                    = $xmlRunSetup.Configuration.Domain.SysvolPath
                        SafeModeAdministratorPassword = ConvertTo-SecureString -AsPlainText $randomSMpwd -Force
                        DomainNetbiosName             = ($xmlRunSetup.Configuration.Domain.NetBIOS).ToUpper()
                        NoRebootOnCompletion          = $true
                        Confirm                       = $false
                        Force                         = $true
                        SkipPreChecks                 = $true
                        ErrorAction                   = "Stop"
                        WarningAction                 = "SilentlyContinue"
                        informationAction             = "SilentlyContinue"
                    }
                    Try 
                    {
                        Install-ADDSForest @HashArguments | Out-Null
                        
                        $arrayScriptLog += "Installation completed. The server will now reboot."
                        Write-toEventLog INFO $arrayScriptLog
                        Write-Progression -Step Update -Code Success -CursorPosition $CursorPosition
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
                    Catch 
                    {
                        $arrayScriptLog += @("Installation Failed!",($Error[0]).ToString())
                        $HashArgumentsDebug = @("Install-ADDSForest failed with the following arguments:",
                                                "CreateDNSDelegation = $false",
                                                "DatabasePath = $($xmlRunSetup.Configuration.Domain.NtdsPath)",
                                                "DomainMode = $($xmlRunSetup.Configuration.Domain.FunctionalLevel)",
                                                "DomainName = $($xmlRunSetup.Configuration.Forest.FullName)",
                                                "ForestMode = $($xmlRunSetup.Configuration.Forest.FunctionalLevel)",
                                                "LogPath = ""C:\Logs""",
                                                "SysvolPath = $($xmlRunSetup.Configuration.Domain.SysvolPath)",
                                                "SafeModeAdministratorPassword = ConvertTo-SecureString -AsPlainText $randomSMpwd -Force",
                                                "DomainNetbiosName = $(($xmlRunSetup.Configuration.Domain.NetBIOS).ToUpper())",
                                                "NoRebootOnCompletion = $true",
                                                "Confirm = $false",
                                                "Force = $true",
                                                "SkipPreChecks = $true",
                                                "ErrorAction = ""Stop""",
                                                "WarningAction = ""SilentlyContinue""",
                                                "informationAction = ""SilentlyContinue""",
                                                "progressAction = ""SilentlyContinue"""
                        )
                        Write-toEventLog Error $arrayScriptLog
                        Write-toEventLog Warning $HashArgumentsDebug
                        Write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                    }
                }
            }
            #endregion
            #region is a domain member.
            $true
            {
                # Action result counters
                $isSuccess = 0
                $isWarning = 0
                $isFailure = 0

                # PingCastle Script Fixes
                $PCFixList  = @('S-ADRegistration','S-DC-SubnetMissing','S-DC-SubnetMissing-IPv6','S-PwdNeverExpires','P-RecycleBin','P-SchemaAdmin')
                $PCFixList += @('P-UnprotectedOU','A-MinPwdLen','A-PreWin2000AuthenticatedUsers','A-LAPS-NOT-Installed','P-Delegated')
                foreach ($Resolution in $PCFixList) 
                {
                    $CursorPosition = Write-Progression -Step Create -Message "Fixing PingCastle alert...: $Resolution"
                    Write-Progression -Step Update -code Running -CursorPosition $CursorPosition

                    # Calling the fix
                    $fixResult = &"resolve-$($Resolution -replace '-','')"

                    # Switching display based on returned value
                    switch ($fixResult) 
                    {
                        "Info" 
                        { 
                            Write-Progression -Step Update -code Success -CursorPosition $CursorPosition
                            $isSuccess++
                        }
                        "Warning" 
                        {
                            Write-Progression -Step Update -code Warning -CursorPosition $CursorPosition
                            $isWarning++
                        }
                        "Error" 
                        {
                            Write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                            $isFailure++
                        }
                    }
                }

                # PurpleKnight Script Fixes
                $PKFixList  = @('Protected-Users','LDAPS-required')
                foreach ($Resolution in $PKFixList) 
                {
                    $CursorPosition = Write-Progression -Step Create -message "Fixing PurpleKnight alert.: $Resolution"
                    Write-Progression -Step Update -code Running -CursorPosition $CursorPosition

                    # Calling the fix
                    $fixResult = &"resolve-$($Resolution -replace '-','')"
                    
                    # Switching display based on returned value
                    switch ($fixResult) 
                    {
                        "Info" 
                        { 
                            Write-Progression -Step Update -code Success -CursorPosition $CursorPosition
                            $isSuccess++
                        }
                        "Warning" 
                        {
                            Write-Progression -Step Update -code Warning -CursorPosition $CursorPosition
                            $isWarning++
                        }
                        "Error" 
                        {
                            Write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                            $isFailure++
                        }
                    }
                }

                # Import GPO
                foreach ($GPO in $xmlDomainSettings.Settings.GroupPolicies.Gpo) 
                {
                    $CursorPosition = Write-Progression -Step Create -message "Adding Security GPO.......: $($GPO.Name)"
                    Write-Progression -Step Update -code Running -CursorPosition $CursorPosition
                    Try 
                    {
                        $gpChek = Get-GPO -Name $GPO.Name -ErrorAction SilentlyContinue
                        if ($gpChek) 
                        {
                            Write-ToEventLog -EventType WARNING -EventMsg "GPO $($GPO.Name): already imported."
                            Write-Progression -Step Update -code Warning -CursorPosition $CursorPosition
                            $isWarning++
                        }
                        Else 
                        {
                            $gpPath = (Get-AdDomain).DistinguishedName
                            if ($GPO.Linkage -eq "DC") 
                            {
                                $gpPath = "OU=Domain Controllers,$gpPath"
                            }
                            [void](New-Gpo -Name $gpo.Name -ErrorAction Stop)
                            [void](Import-GPO -BackupId $GPO.BackupId -TargetName $gpo.Name -Path $PSScriptRoot\Imports\$($GPO.Name) -ErrorAction Stop)
                            [void](New-GPLink -Name $gpo.Name -Target $gpPath -LinkEnabled Yes -Order 1 -ErrorAction Stop)
                            
                            Write-ToEventLog -EventType INFO -EventMsg "GPO $($GPO.Name): imported successfully."
                            Write-Progression -Step Update -Code Success -CursorPosition $CursorPosition
                            $isSuccess++
                        }
                    }
                    Catch 
                    {
                        Write-ToEventLog -EventType Error -EventMsg "GPO $($GPO.Name): import failed! Error: $($_.ToString())"
                        Write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                        $isFailure++                
                    }
                }

                # Import delegation
                foreach ($Deleg in $xmlDomainSettings.Settings.Delegations.Delegation) 
                {
                    $CursorPosition = Write-Progression -Step Create -message "Setting-up delegation.....: $($Deleg.Name)"
                    Write-Progression -Step Update -code Running -CursorPosition $CursorPosition

                    $fixResult = &"$($Deleg.Name)"
                    # Switching display based on returned value
                    switch ($fixResult) 
                    {
                        "Info" 
                        { 
                            Write-Progression -Step Update -code success -CursorPosition $CursorPosition
                            $isSuccess++
                        }
                        "Warning" 
                        {
                            Write-Progression -Step Update -code Warning -CursorPosition $CursorPosition
                            $isWarning++
                        }
                        "Error" 
                        {
                            Write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                            $isFailure++
                        }
                    }
                }

                # Result Array for final display
                $Results = New-Object -TypeName psobject -Property @{Success=$isSuccess ; Warning=$isWarning ; Error=$isFailure}
                $Results | Select-Object Success,Warning,Error | Format-Table -AutoSize

                # Final action: reboot
                $UserDeclined = Write-WarningText -Id FinalAction
                if ($UserDeclined) 
                {
                    Write-toEventLog -EventType Warning -EventMsg @("User has canceled the reboot.",'But I give no care, that is to be done.','...','Wait, he is my master...','Damned. No reboot...',' ',"END: invoke-HelloMyDir")
                    Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
                    Exit 0
                } 
                Else 
                {
                    Restart-Computer -force | Out-Null
                }
            }
            #endregion
        }
    }
    #endregion
    #region new dc
    "Add new DC"
    {
        $arrayScriptLog = @('PHASE EXTEND: ADD A DC.',' ')
        $CursorPosition = Write-Progression -Step Create -Message "Getting Computer informations"
        write-Progression -Step Update -code Running -CursorPosition $CursorPosition
        Try 
        {
            $ProgressPreference = "SilentlyContinue"
            $CsComputer = Get-ComputerInfo
            write-Progression -Step Update -Code Success -CursorPosition $CursorPosition
        }
        Catch 
        {
            write-Progression -Step Update -code Error -CursorPosition $CursorPosition
            $arrayScriptLog += "Failed to get computer informations! Error: $($_.ToString())"
            $prerequesiteKO = $True
        }

        # If this is a domain member or standalone server, then we can install.
        # DomainRole acceptable value: https://learn.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.domainrole?view=powershellsdk-7.4.0
        if ($CsComputer.CsDomainRole -eq 2 -or $CsComputer.CsDomainRole -eq 3) 
        {
            # Install Prerequesites
            $arrayScriptLog += "The system is in an expected state (CsCDomainRole: $($CsComputer.CsDomainRole))"
        
            # Check if prerequesite are installed.
            # Dealing with binaries to install
            $reqBinaries = @('AD-Domain-Services','RSAT-AD-Tools','RSAT-DNS-Server','RSAT-DFS-Mgmt-Con','GPMC')

            $ProgressPreference = "SilentlyContinue"
            foreach ($ReqBinary in $reqBinaries) 
            {
                $CursorPosition = Write-Progression -Step Create -Message "binaries installation.....: $ReqBinary"
                write-Progression -Step Update -code Running -CursorPosition $CursorPosition
                Try 
                {
                    install-windowsFeature -Name $ReqBinary -IncludeAllSubFeature -ErrorAction Stop | Out-Null
                    write-Progression -Step Update -code Success -CursorPosition $CursorPosition
                    $arrayScriptLog += "$($ReqBinary): installed sucessfully."
                }
                Catch 
                {
                    write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                    $arrayScriptLog += "$($ReqBinary): Failed to install! Error: $($_.ToString())"
                    $prerequesiteKO = $True
                }
            }
            $ProgressPreference = "Continue"

            $DJoinUsr = $xmlRunSetup.Configuration.ADObjects.Users.DomainJoin
            $DomainFN = $xmlRunSetup.Configuration.domain.FullName
            $DomainNB = $xmlRunSetup.Configuration.domain.NetBIOS
            
            # is not domain member
            $CursorPosition = Write-Progression -Step Create -Message 'Promoting the server as domain member'
            write-Progression -Step Update -code Running -CursorPosition $CursorPosition
            if ($CsComputer.CsDomainRole -eq 2) 
            {
                $arrayScriptLog += @(" ","The server is not a domain member: the server will be joined to the domain first.")
                try 
                {
                    [void](Add-Computer -DomainName $DomainFN -Credential (Get-Credential -Message 'Enter credential to join this computer to the domain' -User "$DomainNB\$DJoinUsr"))
                    write-Progression -Step Update -code Success -CursorPosition $CursorPosition
                    $arrayScriptLog += @(" ","The server will reboot - rerun the script to make it a domain controller.")

                    Write-Host
                    Write-Host "IMPORTANT!" -ForegroundColor Black -BackgroundColor Red
                    Write-Host "The server have to reboot to finalize the domain joining process." -ForegroundColor White
                    Write-Host "Rerun the script to make it a DC." -ForegroundColor Yellow
                    Write-Host 
                    Write-Host "Press any key to let the server reboot once you're ready..." -ForegroundColor DarkGray -NoNewline
                    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
                    Write-Host
                    $ProgressPreference = "Continue"
                    Write-toEventLog Info $arrayScriptLog
                    Restart-Computer -Force | out-null
                    Exit 0
                }
                Catch 
                {
                    write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                    $arrayScriptLog += @("Error! The server failed to join the domain!",' ',"Error: $($_.ToString())")
                    Write-Host "`nError! Failed to join the domain!`nError: $($_.ToString())`n" -ForegroundColor Red
                    Write-toEventLog Error $arrayScriptLog
                    Exit 2
                }
            }
            Else 
            {
                write-Progression -Step Update -code success -CursorPosition $CursorPosition
                $arrayScriptLog += @(" ","The server is a domain member (prerequesite to domain join with a protected users account)")
            }

            # add DC 
            if (-not($prerequesiteKO)) 
            {
                # Check that the user is a domain account and not local account
                $CursorPosition = Write-Progression -Step Create -Message "Ensure the script is run with a domain account"
                Write-Progression -Step Update -Code Running -CursorPosition $CursorPosition
                
                $USerWhoAmI = WhoAmI
                if ($USerWhoAmI -match "$($ENV:ComputerName)")
                {
                    # Erratum
                    write-Progression -Step Update -Code Error -CursorPosition $CursorPosition
                    $arrayScriptLog += @(' ','Error: the current user is not a domain user.')
                    Write-ToEventLog Error $arrayScriptLog
                    Write-Host "`nError: your are not loggin with a domain account! The script will leave.`n" -ForegroundColor Red
                    Exit 3
                }
                Else 
                {
                    write-Progression -Step Update -Code Success -CursorPosition $CursorPosition
                    $arrayScriptLog += @(' ','The current user is a domain user.')
                    
                    # well, is the user BA, DA or EA?
                    $CursorPosition = Write-Progression -Step Create -Message "Ensure the user is granted BA, DA or EA privileges"
                    Write-Progression -Step Update -Code Running -CursorPosition $CursorPosition
                    
                    Try
                    {
                        $BAName = (Get-ADGroup "S-1-5-32-544" -ErrorAction Stop).Name
                        $DAsid  = [String](Get-ADDomain $DomainFN -ErrorAction Stop).DomainSID.Value + "-512"
                        $DAName = (Get-ADGroup $DAsid -Server $DomainFN -ErrorAction Stop).Name
                        $EAsid  = [String](Get-ADDomain $DomainFN -ErrorAction Stop).DomainSID.Value + "-519"
                        $EAName = (Get-ADGroup $EAsid -Server $DomainFN -ErrorAction Stop).Name
                    }
                    Catch
                    {
                        # Query failed, emergency exit.
                        write-Progression -Step Update -Code Error -CursorPosition $CursorPosition
                        $arrayScriptLog += @(' ','Error: something went wrong while querying AD for BA, DA and EA group names!')
                        Write-ToEventLog Error $arrayScriptLog
                        Write-Host "`nError: Could not query properly AD! The script will leave.`n" -ForegroundColor Red
                        Exit 998
                    }

                    $UserGroups = Get-ADPrincipalGroupMembership $env:username -ErrorAction SilentlyContinue | Select-Object name
                    if ($UserGroups.Name -match $BAName -or $UserGroups.Name -match $DAName -or $UserGroups.Name -match $EAName)
                    {
                        write-Progression -Step Update -Code success -CursorPosition $CursorPosition
                        $arrayScriptLog += @('The account is member of either BA, DA and/or EA.')
                    }
                    Else 
                    {
                        write-Progression -Step Update -Code Error -CursorPosition $CursorPosition
                        $arrayScriptLog += @(' ','Error: the used account is not member of BA, DA or EA group!')
                        Write-ToEventLog Error $arrayScriptLog
                        Write-Host "`nError: The account used is not granted expected rights to perform a DC promotion.`n" -ForegroundColor Red
                        Exit 4
                    }
                }

                # reset ACL and owner
                $CursorPosition = Write-Progression -Step Create -Message "Reseting owner and SDDL for security purpose"
                write-Progression -Step Update -code Running -CursorPosition $CursorPosition
                $NoError = $True
                Try 
                {
                    $Cptr   = Get-ADComputer $env:computername -Properties nTSecurityDescriptor -ErrorAction Stop
                    $Array  = New-Object psobject -Property @{  DistinguishedName = $Cptr.DistinguishedName
                                                                DNSHostName       = $Cptr.DNSHostName
                                                                Enabled           = $Cptr.Enabled
                                                                Name              = $Cptr.Name
                                                                ObjectClass       = $Cptr.ObjectClass
                                                                ObjectGUID        = $Cptr.ObjectGUID
                                                                SamAccountName    = $Cptr.SamAccountName
                                                                SID               = $Cptr.SID
                                                                Owner             = $Cptr.nTSecurityDescriptor.owner }
                }
                Catch 
                {
                    $NoError = $False
                    $arrayScriptLog += @(' ',"Could not get computer data to reset owner/sddl!","Error:$($_.ToString())")
                }
                
                Try 
                {
                    # Reset owner
                    $SamAccountName = $Array.SamAccountName
                    $TargetObject = Get-ADComputer $SamAccountName -Server $DomainFN -ErrorAction Stop
                    $AdsiTarget = [adsi]"LDAP://$DomainFN/$($TargetObject.DistinguishedName)"
                    $NewOwner = New-Object System.Security.Principal.NTAccount($DAName)
                    $AdsiTarget.PSBase.ObjectSecurity.SetOwner($NewOwner)
                    $AdsiTarget.PSBase.CommitChanges()
                }
                Catch 
                {
                    $NoError = $False
                    $arrayScriptLog += @(' ',"Could not reset owner!","Error:$($_.ToString())")
                }
                
                # Sleep
                Start-Sleep -Seconds 10
                
                # Reset ACL
                Try 
                {
                    # Get computer default ACL
                    $SchemaNamingContext = (Get-ADRootDSE -Server $DomainFN -ErrorAction Stop).schemaNamingContext
                    $DefaultSecurityDescriptor = Get-ADObject -Identity "CN=Computer,$SchemaNamingContext" -Properties defaultSecurityDescriptor -ErrorAction Stop | Select-Object -ExpandProperty defaultSecurityDescriptor
                    # Reset ACL to default
                    $ADObj = Get-ADComputer -Identity $SamAccountName -Properties nTSecurityDescriptor -ErrorAction Stop
                    $ADObj.nTSecurityDescriptor.SetSecurityDescriptorSddlForm( $DefaultSecurityDescriptor )
                    Set-ADObject -Identity $ADObj.DistinguishedName -Replace @{ nTSecurityDescriptor = $ADObj.nTSecurityDescriptor } -Confirm:$false 
                }
                Catch 
                {
                    $NoError = $False
                    $arrayScriptLog += @(' ',"Could not reset SDDL!","Error:$($_.ToString())")
                }
                if ($NoError) 
                {
                    write-Progression -Step Update -code Success -CursorPosition $CursorPosition
                    $arrayScriptLog += @(" ","The computer object is now safe and secure.")
                }
                Else 
                {
                    write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                    $arrayScriptLog += @(" ","The computer object has a wrong owner and/or SDDL are unsafe!")
                }

                # deploy ADDS
                $CursorPosition = Write-Progression -Step Create -Message "Installing your new domain controller in $($DomainFN.ToUpper())"
                write-Progression -Step Update -code Running -CursorPosition $CursorPosition

                # Snooze progress bar
                $ProgressPreference = "SilentlyContinue"

                # Start installation...
                $randomSMpwd = New-RandomComplexPasword -Length 24 -AsClearText
                $HashArguments = @{
                    Credential                    = $Creds
                    DatabasePath                  = $xmlRunSetup.Configuration.Domain.NtdsPath
                    DomainName                    = $xmlRunSetup.Configuration.domain.FullName
                    SysvolPath                    = $xmlRunSetup.Configuration.Domain.SysvolPath
                    SafeModeAdministratorPassword = ConvertTo-SecureString -AsPlainText $randomSMpwd -Force
                    NoRebootOnCompletion          = $true
                    Confirm                       = $false
                    Force                         = $true
                    SkipPreChecks                 = $true
                    ErrorAction                   = "Stop"
                    WarningAction                 = "SilentlyContinue"
                    informationAction             = "SilentlyContinue"
                }
                Try 
                {
                    Install-ADDSDomainController @HashArguments | Out-Null
                
                    write-Progression -Step Update -code Success -CursorPosition $CursorPosition
                }
                Catch 
                {
                    $arrayScriptLog += @("Installation Failed!","Error: $($_.ToString())")
                    $arrayScriptLog += @("Install-ADDSDomainController failed with the following arguments:",
                                "Credential = (cyphered data)",
                                "DatabasePath = $($xmlRunSetup.Configuration.Domain.NtdsPath)",
                                "DomainName = $($xmlRunSetup.Configuration.Forest.FullName)",
                                "SysvolPath = $($xmlRunSetup.Configuration.Domain.SysvolPath)",
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
                    Write-toEventLog Error $arrayScriptLog
                    write-Progression -Step Update -code Error -CursorPosition $CursorPosition
                }

                # setup for ldaps
                $CursorPosition = Write-Progression -Step Create -Message "Setup certificate for LDAPS"
                write-Progression -Step Update -code Running -CursorPosition $CursorPosition
                $arrayScriptLog += @(' ','Installing a certificate for ldaps...')
                Try 
                {
                    # Calling the fix
                    $fixResult = &"resolve-LDAPSrequired"
                    # Switching display based on returned value
                    switch ($fixResult) 
                    {
                        "Info" 
                        { 
                            write-Progression -Step Update -code Success -CursorPosition $CursorPosition
                            $arrayScriptLog += 'Certificate installed.'
                        }
                        "Warning" 
                        {
                            write-Progression -Step Update -code Warning -CursorPosition $CursorPosition
                            $arrayScriptLog += 'WARNING: seems that the certificate was not copied in the root store.'
                        }
                        "Error" 
                        {
                            write-Progression -step Update -code Error -CursorPosition $CursorPosition
                            $arrayScriptLog += 'ERROR: failed to create the certificate!'
                        }
                    }
                }
                Catch 
                {
                    write-Progression -step Update -code Error -CursorPosition $CursorPosition
                    Write-Host $arrayRsltTxt[2] -ForegroundColor $arrayColrTxt[2]
                }

                # Final Reboot
                $arrayScriptLog += "Installation completed. The server will now reboot."
                Write-toEventLog $fixResult $arrayScriptLog

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
            }
            else 
            {
                $arrayScriptLog += @("Error! The system is not in an expected state! Error: CsDomainMode is $($CsComputer.CsDomainMode) ; Allowed value are 2 and 3.","More information here: https://learn.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.domainrole?view=powershellsdk-7.4.0")
            }
        }
    }
    #endregion
}

# Exit
Write-toEventLog -EventType INFO -EventMsg "END: invoke-HelloMyDir"
Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
Exit 0