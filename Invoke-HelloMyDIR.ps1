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
if (-not(Test-Path .\Configuration\RunSetup.xml) -and -not($Prepare)) {
    $DbgLog += 'No option used: as the file RunSetup.xml is missing, the script will enfore -Prepare to True.'
    $Prepare = $true
}

Write-toEventLog -EventType INFO -EventMsg $DbgLog | Out-Null
$DbgLog = $null

# USE CASE 1: PREPARE XML SETUP FILE
if ($Prepare) {

    # Test if a configuration file already exists - if so, we will use it.
    $DbgLog = @('PHASE INIT: TEST IF A PREVIOUS RUN IS DETECTED.')

    if (Test-Path .\Configuration\RunSetup.xml) {
    
        # A file is present. We will rename it to a previous version to read old values and offers them as default option.
        $DbgLog += 'The file ".\Configuration\RunSetup.xml" is present, it will be converted to the last backup file.'
    
        if (Test-Path .\Configuration\RunSetup.last) {
    
            $DbgLog += 'As a file named ".\Configuration\RunSetup.last" is already present, this file will overwrite the existing one.'
    
            Remove-Item -Path .\Configuration\RunSetup.last -Force | Out-Null
            Rename-item -Path .\Configuration\RunSetup.xml -NewName .\Configuration\RunSetup.last -ErrorAction SilentlyContinue | Out-Null
            
            # Loading .last file as default option for the script.
            $DbgLog += 'As a file named ".\Configuration\RunSetup.last" is already present, this file will overwrite the existing one.'
            $DefaultChoices = Get-XmlContent .\Configuration\RunSetup.last -ErrorAction SilentlyContinue
        }
    
        Else {
            $DbgLog += 'No previous run detected.'
        }
    }
    
    Write-toEventLog INFO $DbgLog | Out-Null
    $DbgLog = $null

    # Preload previous run options
    $DbgLog = @('XML BUILDERS: PRELOAD ANSWERS FROM PREVIOUS RUN.')

    if (Test-Path .\Configuration\RunSetup.last) {
        Try {
    
            $lastRunOptions = Get-XmlContent -XmlFile .\Configuration\RunSetup.last -ErrorAction Stop
            $DbgLog += @('Variable: LastRunOptions','Loaded with .\Configuration\RunSetup.last xml data.')
            Write-toEventLog INFO $DbgLog | Out-Null
        }
        Catch {
    
            $lastRunOptions = $null
            $DbgLog += @('Variable: $LastRunOptions','Failed to be loaded with .\Configuration\RunSetup.last xml data.')
            Write-toEventLog WARNING $DbgLog | Out-Null
        }
    }
    $DbgLog = $null

    #Load Script Settings XML
    $ScriptSettings = Get-XmlContent .\Configuration\ScriptSettings.xml

    # Create XML settings file
    $DbgLog = @('XML BUILDERS: CREATE XML SETUP FILE')
    $RunSetup = New-XmlContent -XmlFile .\Configuration\RunSetup.xml
    
    if ($RunSetup) {
   
        $DbgLog += @("File .\Configuration\RunSetup.xml created.","The file will now be filled with user's choices.")
        $RunSetup.WriteStartElement('HmDSetup')
   
        Write-toEventLog INFO $DbgLog | Out-Null
        $DbgLog = $null
    }
    Else {
   
        $DbgLog += @("FATAL ERROR: the file .\Configuration\RunSetup.xml could not be created.","The script will end with error code 2.")
        Write-toEventLog ERROR $DbgLog | Out-Null
        Write-Error "ERROR: THE CONFIGURATION FILE COULD NOT BE CREATED."
        Exit 2
    }

    # Say Hello
    $ScriptTitle = @(' ',"$([Char]0x2554)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2557)" `
                        ,"$([Char]0x2551) Hello My DIR! $([Char]0x2551)" `
                        ,"$([Char]0x2551) version 1.0.0 $([Char]0x2551)" `
                        ,"$([Char]0x2551) Lic. GNU GPL3 $([Char]0x2551)" `
                        ,"$([Char]0x255A)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x2550)$([Char]0x255D)" `
                        ,' ')
    Write-TitleText -Text $ScriptTitle
    
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

    # Inquiring for setup data: context
    ## New forest?
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
    $CursorPosition = $Host.UI.RawUI.CursorPosition
    for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
        $StringCleanSet += " " 
    }

    ### Querying input
    $isKO = $True
    While ($isKO)
    {
        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
        if ($key.VirtualKeyCode -eq 89 -or $key.VirtualKeyCode -eq 13)
        {
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "Yes" -ForegroundColor White
            $Choice = "Yes"
            $isKO = $false
        }
        elseif ($key.VirtualKeyCode -eq 78) {
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "No" -ForegroundColor Red
            $Choice = "No"
            $isKO = $false
        }
        Else {
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
            $isKO = $true
        }
    }

    # Inquiring for setup data: the forest.
    $DbgLog = @("SETUP DATA COLLECT: FOREST"," ")

    ## Writing result to XML.
    $RunSetup.WriteStartElement('Configuration')
    $RunSetup.WriteStartElement('Forest')
    $RunSetup.WriteElementString('Installation',$Choice)
    $DbgLog += @("Install a new forest: $Choice")

    ## Forest Root Domain Fullname
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.Name

    ## Forest Root Domain NetBIOS
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.NetBIOS

    ## Forest FFL
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.FunctionalLevel

    ## Forest DFL
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.FunctionalLevel

    ## Forest Root domain SafeMode Admin Pwd
    ## The default password is generated by the function as clear text. It will not be written to any file.
    $ProposedAnswer = New-RandomComplexPasword -Length 24 -AsClearText

    ## Forest Database path
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.Path.NTDS

    # # Forest Sysvol path
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.Domain.Path.SysVol

    ## Forest Optional Attributes: Recycle Bin
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.ADRecycleBin

    ## Forest Optional Attributes: Privileged Access Management
    $ProposedAnswer = $DefaultChoices.HmDSetup.Forest.ADPAM

    ## Closing Forest element
    $RunSetup.WriteEndElement()

    # Closing RunSetup.xml
    $RunSetup.WriteEndDocument()
    $RunSetup.Flush()
    $RunSetup.Close()
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