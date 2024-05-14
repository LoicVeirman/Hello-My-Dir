<#
    .SYNOPSIS
    This is the main script of the project "Hello my Dir!".

    .COMPONENT
    PowerShell v5 minimum.

    .DESCRIPTION
    This is the main script to execute the project "Hello my Dir!". This project is intended to ease in building a secure active directory from scratch and maintain it afteward.

    .EXAMPLE
    .\HelloMyDir.ps1 -Prepare
    Will only query for setup data (generate the RunSetup.xml file). 

    .EXAMPLE
    .\HelloMyDir.ps1
    Will run the script for installation purpose (or failed if not RunSetup.xml is present). 

    .NOTES
    Version.: 01.00.000
    Author..: Loic VEIRMAN (MSSec)
    History.: 
    01.00.000   Script creation.
#>
Param(
    [Parameter(Position=0)]
    [switch]
    $Prepare
)

# Load modules. If a module fails on load, the script will stop.
Try {
    Import-Module -Name (Get-ChildItem .\Modules).FullName -ErrorAction Stop | Out-Null
}
Catch {
    Write-Error "Failed to load modules."
    Exit 1
}

# Initiate logging
$DbgLog = @('START: invoke-HelloMyDir')
Test-EventLog | Out-Null

if ($Prepare) {
    $DbgLog += 'Option "Prepare" declared: the file RunSetup.xml will be generated'
} 
else {
    $DbgLog += 'No option used: the setup will perform action to configure your AD.'
}

# CHECK FOR FIRST RUN
if (-not(Test-Path .\Configuration\RunSetup.xml)) {
    $DbgLog += 'No option used: as the file RunSetup.xml is missing, the script will enfore -Prepare to True.'
    New-HMDRunSetupXml | Out-Null
    $Prepare = $true
}

Write-toEventLog -EventType INFO -EventMsg $DbgLog | Out-Null
$DbgLog = $null

# USE CASE 1: PREPARE XML SETUP FILE
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

    # Load Script Settings XML
    $ScriptSettings = Get-XmlContent .\Configuration\ScriptSettings.xml

    # Say Hello: Write Header
    Clear-Host
    $ScriptTitle = @(' ',"$([Char]0x2554)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2557)" `
                        ,"$([Char]0x2551) Hello My DIR! $([Char]0x2551)" `
                        ,"$([Char]0x2551) version 1.0.0 $([Char]0x2551)" `
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

    # Inquiring for setup data: Forest
    $DbgLog = @("SETUP DATA COLLECT: FOREST"," ")

    ## Is it a new forest?
    ### Calling Lurch from Adam's family...
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

    ### Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='001']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-YesNoChoice $toDisplayArr
    
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
            # Is do it again!
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
    $ForestData = Get-HmDForest $ForestChoice $RunSetup

    ## Forest Root Domain Fullname
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.Name
    

    ## Forest Root Domain NetBIOS
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.NetBIOS

    ## Forest FFL
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.FunctionalLevel

    ## Forest DFL
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.FunctionalLevel

    ## Forest Root domain SafeMode Admin Pwd
    ## The default password is generated by the function as clear text. It will not be written to any file.
    #$ProposedAnswer = New-RandomComplexPasword -Length 24 -AsClearText

    ## Forest Database path
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.Path.NTDS

    # # Forest Sysvol path
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.Path.SysVol

    ## Forest Optional Attributes: Recycle Bin
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.ADRecycleBin

    ## Forest Optional Attributes: Privileged Access Management
    #$ProposedAnswer = $DefaultChoices.HmDSetup.Forest.ADPAM

    # Saving RunSetup.xml
    $RunSetup.save((Resolve-Path .\Configuration\RunSetup.xml).Path)
    $DbgLog += @('File RunSetup.xml updated and saved.',' ')
    Write-toEventLog INFO $DbgLog | Out-Null
}
# USE CASE 2: SETUP AD
Else {

}

# Exit
Write-toEventLog -EventType INFO -EventMsg "END: invoke-HelloMyDir"
Remove-Module -Name (Get-ChildItem .\Modules).Name -ErrorAction SilentlyContinue | Out-Null
Exit 0