<#
    THIS MODULE CONTAINS FUNCTIONS ONLY USABLE BY HELLO MY DIR.
#>
Function New-HmDRunSetupXml {
    <#
        .SYNOPSIS
        Create an empty runSetup.xml file.

        .DESCRIPTION
        The file runSetup.xml is a prerequesite for the script to run. This function generates one with no value set.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05.14 -- Script creation.
    #>
    Param()

    # No logging.
    # Create xml file
    $myXml = New-XmlContent -XmlFile .\Configuration\RunSetup.xml

    # Add content
    # - Start: Configuration
    $myXml.WriteStartElement('Configuration')
    # - Start: Forest
    $myXml.WriteStartElement('Forest')
    $myXml.WriteElementString('Installation','')
    $myXml.WriteElementString('FullName','')
    $myXml.WriteElementString('NetBIOS','')
    $myXml.WriteElementString('FunctionalLevel','')
    $myXml.WriteElementString('RecycleBin','')
    $myXml.WriteElementString('PAM','')
    # - End: Forest
    $myXml.WriteEndElement()
    # - Start: Domain
    $myXml.WriteStartElement('Domain')
    $myXml.WriteElementString('Type','')
    $myXml.WriteElementString('FullName','')
    $myXml.WriteElementString('NetBIOS','')
    $myXml.WriteElementString('FunctionalLevel','')
    $myXml.WriteElementString('SysvolPath','')
    $myXml.WriteElementString('NtdsPath','')
    # - End: Domain
    $myXml.WriteEndElement()
    # - End: Configuration
    $myXml.WriteEndElement()

    # Closing document
    $MyXml.WriteEndDocument()
    $myXml.Flush()
    $myXml.Close()
}
Function Get-HmDForest {
    <#
        .SYNOPSIS
        Collect data about the target forest where the new domain will be installed.

        .DESCRIPTION
        Collect data about the forest in which a new domain will be created. Return an array.

        .PARAMETER NewForest
        Parameter indicating wether or not this forest is to be build.

        .PARAMETER PreviousChoices
        XML dataset with previous choices to offer a more dynamic experience.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/10 -- Script creation.
    #>

    [CmdletBinding()]
    param (
        # Forest installation choice
        [Parameter(Mandatory,Position=0)]
        [ValidateSet('Yes','No')]
        [String]
        $NewForest,

        # XML dataset with previous choices
        [Parameter(Mandatory,Position=1)]
        [XML]
        $PreviousChoices
    )

    # Initiate logging. A specific variable is used to inform on the final result (info, warning or error).
    Test-EventLog | Out-Null
    $callStack = Get-PSCallStack
    $CalledBy = ($CallStack[1].Command -split '\.')[0]
    $ExitLevel = 'INFO'
    $DbgLog = @('START: Get-HmDForest',' ','Called by: $CalledBy',' ')

    # Getting previous data
    $ForestDNS = $PreviousChoices.Configuration.Forest.Fullname
    $ForestNtB = $PreviousChoices.Configuration.Forest.NetBIOS
    $ForestFFL = $PreviousChoices.Configuration.Forest.FunctionalLevel
    $ForestBIN = $PreviousChoices.Configuration.Forest.RecycleBin
    $ForestPAM = $PreviousChoices.Configuration.Forest.PAM

    $DbgLog += @('Previous choices:',"> Forest Fullname: $ForestDNS","> Forest NetBIOS name: $ForestNtB","> Forest Functional Level: $ForestFFL","> Enable Recycle Bin: $ForestBIN","> Enable PAM: $ForestPAM",' ')

    # Question: Forest DNS name
    ## Fist, check if the host is member of a domain. If so, the domain will be used as 
    if ((gwmi win32_computersystem).partofdomain -eq $true -and $ForestDNS -ne '' -and $null -ne $ForestDNS) {
            # Set the value as default root domain name
            $ForestDNS = (gwmi win32_computersystem).domain
    }
    ## Now query user
    ### Calling Lurch from Adam's family...
    $ScriptSettings = Get-XmlContent .\Configuration\ScriptSettings.xml
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadInputFormat).Split(';'))

    ### Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='002']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
       
    ### Input time
    ### Get current cursor position and create the Blanco String
    $StringCleanSet = " "
    $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
    for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
        $StringCleanSet += " " 
    }
   
    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition
   
    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $ForestDNS -NoNewline -ForegroundColor Magenta

    <# 
        Analyzing answer.
        Proof and explanation: https://regex101.com/r/FLA9Bv/40
        There're two approaches to choose from when validating domains.
        1. By-the-books FQDN matching (theoretical definition, rarely encountered in practice):
        > max 253 character long (as per RFC-1035/3.1, RFC-2181/11)
        > max 63 character long per label (as per RFC-1035/3.1, RFC-2181/11)@
        > any characters are allowed (as per RFC-2181/11)
        > TLDs cannot be all-numeric (as per RFC-3696/2)
        > FQDNs can be written in a complete form, which includes the root zone (the trailing dot)
        
        2. Practical / conservative FQDN matching (practical definition, expected and supported in practice):
        > by-the-books matching with the following exceptions/additions
        > valid characters: [a-zA-Z0-9.-]
        > labels cannot start or end with hyphens (as per RFC-952 and RFC-1123/2.1)
        > TLD min length is 2 character, max length is 24 character as per currently existing records
        > don't match trailing dot
        The regex below contains both by-the-books and practical rules. 
    #>
    $Regex = '^(?!.*?_.*?)(?!(?:[\w]+?\.)?\-[\w\.\-]*?)(?![\w]+?\-\.(?:[\w\.\-]+?))(?=[\w])(?=[\w\.\-]*?\.+[\w\.\-]*?)(?![\w\.\-]{254})(?!(?:\.?[\w\-\.]*?[\w\-]{64,}\.)+?)[\w\.\-]+?(?<![\w\-\.]*?\.[\d]+?)(?<=[\w\-]{2,})(?<![\w\-]{25})$'

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # relocate cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

        # Getting user $input
        [string]$answer = read-host

        # if $answer is null, then we use the default choice
        if (($answer -eq '' -or $null -eq $answer) -and ($ForestDNS -ne '' -or $null -ne $ForestDNS)) {
            $answer = $ForestDNS
        }

        # if answer is not null, we ensure that the regex for domain is matched
        if ($answer -ne '' -and $null -ne $answer) {
            switch ($answer -match $Regex) {
                $true {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $answer -ForegroundColor Green
                    $isKO = $false
                }
                $False {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
                    $isKO = $true
                }
            }
        }
    }


    ## Writing result to XML
    $PreviousChoices.Configuration.Forest.FullName = $answer

    # Question: netBIOS forest domain
    ## First check if the host is member of a domain. If so, we will use it as default (whenever $forestNtB is null).
    if ($ForestNtB -eq '' -or $null -eq $ForestNtB) {
        $ForestNtB = ($ForestDNS -split '\.')[0]
    }

    ## Now query user
    ### Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='003']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
       
    ### Input time
    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition
   
    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $ForestNtB -NoNewline -ForegroundColor Magenta

    <# 
        Analyzing answer.
        The regex make input match NetBIOS rules (15 char, etc.)
    #>
    $Regex = '^.[a-zA-Z0-9-][a-zA-Z0-9-]{1,14}$'

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # relocate cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

        # Getting user $input
        [string]$answer = read-host

        # if $answer is null, then we use the default choice
        if (($answer -eq '' -or $null -eq $answer) -and ($ForestNtB -ne '' -or $null -ne $ForestNtB)) {
            $answer = $ForestNtB
        }

        # if answer is not null, we ensure that the regex for netbios is matched
        if ($answer -ne '' -and $null -ne $answer) {
            switch ($answer -match $Regex) {
                $true {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $answer -ForegroundColor Green
                    $isKO = $false
                }
                $False {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
                    $isKO = $true
                }
            }
        }
    }

    ## Writing result to XML
    $PreviousChoices.Configuration.Forest.NetBIOS = $answer

    # Question: FFL
    ### Calling Lurch from Adam's family...
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

    $StringCleanSet = " "
    $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
    for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
        $StringCleanSet += " " 
    }
    
    ### Getting option available for this host
    $OSCaption = (gwmi Win32_OperatingSystem).Caption
    $IdRegexFL = ($ScriptSettings.Settings.FunctionalLevel.OS | Where-Object { $OSCaption -match $_.Caption }).Regex
    
    ## Now query user
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='004']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    Write-Host
    Write-InformationalText $toDisplayArr

    ### Display options on screen
    for ($id = 1 ; $id -le 7 ; $id++) {
        if ($id -match $IdRegexFL) {
            Write-Host " [" -ForegroundColor Gray -NoNewline
            Write-Host $id -ForegroundColor Yellow -NoNewline
            Write-Host "] " -ForegroundColor Gray -NoNewline
            Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.ID -eq $id }).Desc) -ForegroundColor White
        }
    }
    ### Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='005']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    Write-Host
    Write-UserChoice $toDisplayArr
    
    ### Input time
    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition
   
    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $ForestFFL -NoNewline -ForegroundColor Magenta

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # relocate cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

        # Getting user $input
        $answer = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")

        # if answer is part of the accepted value, we echo the desc and move next. Else... Lurch?
        if ($answer.character -match $IdRegexFL) {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.Id -eq $answer.character}).Desc) -ForegroundColor Green
                $isKO = $false
            }
        else {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
                $isKO = $true
            }
    }

    ## Writing result to XML
    $PreviousChoices.Configuration.Forest.FunctionalLevel = $answer.character

    # End logging
    Write-toEventLog $ExitLevel $DbgLog | Out-Null

    # Return result
    return $PreviousChoices
}