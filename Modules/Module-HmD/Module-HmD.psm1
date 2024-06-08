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
    $myXml.WriteEndElement()
    # - End: Forest
    # - Start: Domain
    $myXml.WriteStartElement('Domain')
    $myXml.WriteElementString('Type','')
    $myXml.WriteElementString('FullName','')
    $myXml.WriteElementString('NetBIOS','')
    $myXml.WriteElementString('FunctionalLevel','')
    $myXml.WriteElementString('SysvolPath','')
    $myXml.WriteElementString('NtdsPath','')
    $myXml.WriteEndElement()
    # - End: Domain
    # - Start: WindowsFeatures
    $myXml.WriteStartElement('WindowsFeatures')
    $myXml.WriteElementString('AD-Domain-Services','')
    $myXml.WriteElementString('RSAT-AD-Tools','')
    $myXml.WriteElementString('RSAT-DNS-Server','')
    $myXml.WriteElementString('RSAT-DFS-Mgmt-Con','')
    $myXml.WriteElementString('GPMC','')
    $myXml.WriteEndElement()
    # - end: WindowsFeatures
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
    $DbgLog = @('START: Get-HmDForest',' ',"Called by: $($CalledBy)",' ')

    # Getting previous data
    $ForestDNS = $PreviousChoices.Configuration.Forest.Fullname
    $ForestNtB = $PreviousChoices.Configuration.Forest.NetBIOS
    $ForestFFL = $PreviousChoices.Configuration.Forest.FunctionalLevel
    $ForestBIN = $PreviousChoices.Configuration.Forest.RecycleBin
    $ForestPAM = $PreviousChoices.Configuration.Forest.PAM

    $DbgLog += @('Previous choices:',"> Forest Fullname: $ForestDNS","> Forest NetBIOS name: $ForestNtB","> Forest Functional Level: $ForestFFL","> Enable Recycle Bin: $ForestBIN","> Enable PAM: $ForestPAM",' ')

    #############################
    # QUESTION: FOREST DNS NAME #
    #############################
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

    ###################################
    # QUESTION: NETBIOS FOREST DOMAIN #
    ###################################
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

    #####################################
    # QUESTION: FOREST FUNCTIONAL LEVEL #
    #####################################
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
    
    $DbgLog += @("OSCaption is $OSCaption, the Regex will be $IdRegexFL"," ")

    ## Now query user
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='004']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    Write-Host
    Write-InformationalText $toDisplayArr
    Write-Host

    ### Display options on screen
    for ($id = 7 ; $id -ge 1 ; $id--) {
        if ($id -match $IdRegexFL) {
            Write-Host " [" -ForegroundColor White -NoNewline
            Write-Host $id -ForegroundColor Cyan -NoNewline
            Write-Host "] " -ForegroundColor White -NoNewline
            Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.ID -eq $id }).Desc) -ForegroundColor Yellow
        }
    }
    ### Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='005']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    Write-Host
    Write-UserChoice $toDisplayArr

    ### Check if FFL has a value. If not, we will use the maximum level value (which is always seven, yet.)
    if ([String]::IsNullOrEmpty($ForestFFL)) {
        if ($OSCaption -match "2025") { 
            $ForestFFL = "10" 
        } 
        Else { 
            $ForestFFL = "7"
        }
        $DbgLog += @("FFL is empty, forcing to $ForestFFL"," ")
    }
    
    ### Input time
    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition
   
    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.ID -eq $ForestFFL }).Desc) -NoNewline -ForegroundColor Magenta

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # relocate cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

        # Getting user $input
        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")

        # if answer is part of the accepted value, we echo the desc and move next. Else... Lurch?
        if ($key.character -match $IdRegexFL) {
            $ForestFFL = [String]"$($key.character)"
            if ($ForestFFL -eq "0") { 
                $ForestFFL = "10"
            }
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.Id -eq $ForestFFL}).Desc) -ForegroundColor Green
            $isKO = $false
        }
        elseif ($key.VirtualKeyCode -eq 13) {
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.Id -eq $ForestFFL}).Desc) -ForegroundColor Green
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

    # Write to XML
    $PreviousChoices.Configuration.Forest.FunctionalLevel = $ForestFFL

    ############################
    # QUESTION: AD RECYCLE BIN #
    ############################
    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='008']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
    
    ## Yes/No time
    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition

    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $ForestBIN -NoNewline -ForegroundColor Magenta

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        ## Reading key press
        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
        ## Analyzing key pressed
        ## Pressed ENTER
        if ($key.VirtualKeyCode -eq 13) {
            # Is Last Choice or Yes if no previous choice
            if ([String]::IsNullOrEmpty($ForestBIN)) {
                $ForestBIN = "Yes"
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $ForestBIN -ForegroundColor Green
                $isKO = $false
            }
            Else {
                if ($ForestBIN -eq 'No') { $color = 'Red' } Else { $color = 'Green' }
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $ForestBIN -ForegroundColor $color
            }
            $isKO = $false
        }
        ## Pressed Y or y
        Elseif ($key.VirtualKeyCode -eq 89) {
            # Is Yes
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "Yes" -ForegroundColor Green
            $ForestBIN = "Yes"
            $isKO = $false
        }
        ## Pressed N or N
        elseif ($key.VirtualKeyCode -eq 78) {
            # Is No
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "No" -ForegroundColor Red
            $ForestBIN = "No"
            $isKO = $false
        }
        ## Pressed any other key
        Else {
            # Do it again!
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
            $isKO = $true
        }
    }

    ## Writing result to XML
    $PreviousChoices.Configuration.Forest.RecycleBin = $ForestBIN

    ####################
    # QUESTION: AD PAM #
    ####################
    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='009']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
    
    ## Yes/No time
    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition

    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $ForestPAM -NoNewline -ForegroundColor Magenta

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        ## Reading key press
        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
        ## Analyzing key pressed
        ## Pressed ENTER
        if ($key.VirtualKeyCode -eq 13) {
            # Is Last Choice or No if no previous choice
            if ([String]::IsNullOrEmpty($ForestPAM)) {
                $ForestPAM = "No"
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $ForestPAM -ForegroundColor Red
                $isKO = $false
            }
            Else {
                if ($ForestPAM -eq 'No') { $color = 'Red' } Else { $color = 'Green' }
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $ForestPAM -ForegroundColor $color
            }
            $isKO = $false
        }
        ## Pressed Y or y
        Elseif ($key.VirtualKeyCode -eq 89) {
            # Is Yes
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "Yes" -ForegroundColor Green
            $ForestPAM = "Yes"
            $isKO = $false
        }
        ## Pressed N or N
        elseif ($key.VirtualKeyCode -eq 78) {
            # Is No
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "No" -ForegroundColor Red
            $ForestPAM = "No"
            $isKO = $false
        }
        ## Pressed any other key
        Else {
            # Do it again!
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
            $isKO = $true
        }
    }

    ## Writing result to XML
    $PreviousChoices.Configuration.Forest.PAM = $ForestPAM

    # End logging
    Write-toEventLog $ExitLevel $DbgLog | Out-Null

    # Return result
    return $PreviousChoices
}

Function Get-HmDDomain {
    <#
        .SYNOPSIS
        Collect data about the target domain where the new domain will be installed.

        .DESCRIPTION
        Collect data about the domain that will be created. Return an array.

        .PARAMETER NewForest
        Parameter indicating wether or not this forest is to be build.

        .PARAMETER PreviousChoices
        XML dataset with previous choices to offer a more dynamic experience.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/18 -- Script creation.
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
    $DbgLog = @('START: Get-HmDDomain',' ',"Called by: $($CalledBy)",' ')

    # Getting previous data
    $ForestDNS = $PreviousChoices.Configuration.Forest.Fullname
    $ForestNtB = $PreviousChoices.Configuration.Forest.NetBIOS
    $ForestFFL = $PreviousChoices.Configuration.Forest.FunctionalLevel
    $DomainTYP = $PreviousChoices.Configuration.Domain.Type
    $DomainDNS = $PreviousChoices.Configuration.Domain.Fullname
    $DomainNtB = $PreviousChoices.Configuration.Domain.NetBIOS
    $DomainDFL = $PreviousChoices.Configuration.Domain.FunctionalLevel
    $DomainSYS = $PreviousChoices.Configuration.Domain.SysvolPath
    $DomainNTD = $PreviousChoices.Configuration.Domain.NtdsPath

    $DbgLog += @('Previous choices:',"> Domain Type: $domainTYP","> Domain Fullname: $domainDNS","> Domain NetBIOS name: $DomainNtB","> Domain Functional Level: $DomainDFL",' ')    

    # Loading Script Settings
    $ScriptSettings = Get-XmlContent .\Configuration\ScriptSettings.xml

    #########################
    # QUESTION: DOMAIN TYPE #
    #########################
    # If this a new forest, then we already know the domain type. Why ask, then?
    if ($NewForest -eq 'Yes') {
        # Duplicating value
        $DomainTYP = 'Root'
    }
    Else {
        # Enquiring for the new domain type
        ## Calling Lurch from Adam's family...
        $LurchMood = @(($ScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

        ## Display question 
        $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='010']" | Select-Object -ExpandProperty Node
        $toDisplayArr = @($toDisplayXml.Line1)
        $toDisplayArr += $toDisplayXml.Line2
        Write-UserChoice $toDisplayArr

        ## Input time
        ## Get current cursor position and create the Blanco String
        $StringCleanSet = " "
        $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
        for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
            $StringCleanSet += " " 
        }

        ## Getting cursor position for relocation
        $CursorPosition = $Host.UI.RawUI.CursorPosition

        ## Writing default previous choice (will be used if RETURN is pressed)
        if ([string]::IsNullOrEmpty($DomainTYP)) {
            Write-Host "Child" -NoNewline -ForegroundColor Magenta
        } 
        else {
            if ($NewForest -eq 'No' -and $DomainTYP -eq 'Root') {
                # Enforce domain type as this is not a new forest
                $DomainTYP = "Child"
                Write-Host $DomainTYP -NoNewline -ForegroundColor Magenta
            }
            Else {
                Write-Host $DomainTYP -NoNewline -ForegroundColor Magenta
            }
        }
        ### Querying input: waiting for Y,N or ENTER.
        $isKO = $True
        While ($isKO)
        {
            ## Reading key press
            $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
            ## Analyzing key pressed
            ## Pressed ENTER
            if ($key.VirtualKeyCode -eq 13) {
                # Is Last Choice or No if no previous choice
                if ([String]::IsNullOrEmpty($DomainTYP)) {
                    $DomainTYP = "Child"
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $DomainTYP -ForegroundColor Green
                    $isKO = $false
                }
                Else {
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $DomainTYP -ForegroundColor Green
                }
                $isKO = $false
            }
            ## Pressed C or c
            Elseif ($key.VirtualKeyCode -eq 67) {
                # Is Child
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host "Child" -ForegroundColor Green
                $DomainTYP = "Child"
                $isKO = $false
            }
            ## Pressed I or i
            elseif ($key.VirtualKeyCode -eq 73) {
                # Is Isolated
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host "Isolated" -ForegroundColor Green
                $DomainTYP = "Isolated"
                $isKO = $false
            }
            ## Pressed any other key
            Else {
                # Do it again!
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host (Get-Random $LurchMood) -ForegroundColor DarkGray -NoNewline
                $isKO = $true
            }
        }
    }

    ## Writing result to XML
    $PreviousChoices.Configuration.Domain.Type = $DomainTYP

    #########################
    # QUESTION: DOMAIN FQDN #
    #########################
    # IF this is a new forest, then we already have this information. We won't bother you with it, uh?
    if ($NewForest -eq 'Yes') {
        # Duplicating value
        $DomainDNS = $ForestDNS
    }
    Else {
        # Enquiring for the new name
        ## Calling Lurch from Adam's family...
        $LurchMood = @(($ScriptSettings.Settings.Lurch.BadInputFormat).Split(';'))

        ## Display question 
        $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='011']" | Select-Object -ExpandProperty Node
        $toDisplayArr = @($toDisplayXml.Line1)
        $toDisplayArr += $toDisplayXml.Line2
        Write-UserChoice $toDisplayArr
    
        ## Input time
        ## Get current cursor position and create the Blanco String
        $StringCleanSet = " "
        $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
        for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
            $StringCleanSet += " " 
        }

        ## Getting cursor position for relocation
        $CursorPosition = $Host.UI.RawUI.CursorPosition

        ## Writing default previous choice (will be used if RETURN is pressed)
        Write-Host $DomainDNS -NoNewline -ForegroundColor Magenta

        ## Regex validating that the new name is valid
        Switch ($DomainTYP) {
            'Isolated' { $Regex = '^(?!.*?_.*?)(?!(?:[\w]+?\.)?\-[\w\.\-]*?)(?![\w]+?\-\.(?:[\w\.\-]+?))(?=[\w])(?=[\w\.\-]*?\.+[\w\.\-]*?)(?![\w\.\-]{254})(?!(?:\.?[\w\-\.]*?[\w\-]{64,}\.)+?)[\w\.\-]+?(?<![\w\-\.]*?\.[\d]+?)(?<=[\w\-]{2,})(?<![\w\-]{25})$' }
            'Child' { $Regex = ".*\.$ForestDNS$" }
        }

        ### Querying input: waiting for Y,N or ENTER.
        $isKO = $True
        While ($isKO)
        {
            # relocate cursor
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

            # Getting user $input
            [string]$answer = read-host

            # if $answer is null, then we use the default choice
            if ([String]::IsNullOrEmpty($answer)) {
                [string]$answer = $DomainDNS
            }

            # if answer is not null, we ensure that the regex for domain is matched
            if (-not([String]::IsNullOrEmpty($answer)) -and ($answer -ne $ForestDNS)) {
                switch ($answer -match $Regex) {
                    $true {
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                        Write-Host $StringCleanSet -NoNewline
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                        Write-Host $answer -ForegroundColor Green
                        $DomainDNS = $answer
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
            Else {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host "Don't try to fool me..." -ForegroundColor DarkGray -NoNewline
                $isKO = $true
            }
        }
    }

    ## Writing result to XML
    $PreviousChoices.Configuration.Domain.FullName = $DomainDNS

    #################################
    # QUESTION: DOMAIN NETBIOS NAME #
    #################################
    # IF this is a new forest, then we already have this information. We won't bother you with it, uh?
    if ($NewForest -eq 'Yes') {
        # Duplicating value
        $DomainNtB = $ForestNtB
    }
    Else {
        # Enquiring for the new name
        ## Display question 
        $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='012']" | Select-Object -ExpandProperty Node
        $toDisplayArr = @($toDisplayXml.Line1)
        $toDisplayArr += $toDisplayXml.Line2
        Write-UserChoice $toDisplayArr
    
        ## Input time
        ## Get current cursor position and create the Blanco String
        $StringCleanSet = " "
        $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
        for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
            $StringCleanSet += " " 
        }

        ## Getting cursor position for relocation
        $CursorPosition = $Host.UI.RawUI.CursorPosition

        ## Writing default previous choice (will be used if RETURN is pressed)
        if([String]::IsNullOrEmpty($DomainNtB)) {
            # If no data, then we use the first part from the dns name.
            $DomainNtB = ($DomainDNS -split "\.")[0]
        }
        Write-Host $DomainNtB -NoNewline -ForegroundColor Magenta

        ## Regex validating that the new name is valid
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
            if ([String]::IsNullOrEmpty($answer)) {
                [string]$answer = $DomainNtB
            }

            # if answer is not null, we ensure that the regex for domain is matched
            if (-not([String]::IsNullOrEmpty($answer)) -and ($answer -ne $ForestNtB)) {
                switch ($answer -match $Regex) {
                    $true {
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                        Write-Host $StringCleanSet -NoNewline
                        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                        Write-Host $answer -ForegroundColor Green
                        $DomainNtB = $answer
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
            Else {
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host "Don't try to fool me..." -ForegroundColor DarkGray -NoNewline
                $isKO = $true
            }
        }
    }
    
    ## Writing result to XML
    $PreviousChoices.Configuration.Domain.NetBIOS = $DomainNtB

    #####################################
    # QUESTION: DOMAIN FUNCTIONAL LEVEL #
    #####################################
    # Enquiring for the new name
    ## Calling Lurch from Adam's family...
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

    # Regex computing
    $IdRegexFL = ($ScriptSettings.Settings.FunctionalLevel.OS | Where-Object { $OSCaption -match $_.Caption }).Regex

    # Alert User on avail' choices
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='004']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    Write-Host
    Write-InformationalText $toDisplayArr
    Write-Host

    ### Display options on screen
    for ($id = 7 ; $id -ge 1 ; $id--) {
        if ($id -match $IdRegexFL -and $id -ge $ForestFFL) {
            Write-Host " [" -ForegroundColor White -NoNewline
            Write-Host $id -ForegroundColor Cyan -NoNewline
            Write-Host "] " -ForegroundColor White -NoNewline
            Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.ID -eq $id }).Desc) -ForegroundColor Yellow
        }
    }
    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='013']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-Host
    Write-UserChoice $toDisplayArr
    
    ## Input time
    ## Get current cursor position and create the Blanco String
    $StringCleanSet = " "
    $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
    for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
        $StringCleanSet += " " 
    }

    ## Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition

    ## Writing default previous choice (will be used if RETURN is pressed)
    if ([string]::IsNullOrEmpty($DomainDFL)) {
        $DomainDFL = $ForestFFL
        $DbgLog += @("Domain DFL is empty, forced to $DomainDFL")
    }

    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.ID -eq $DomainDFL }).Desc) -NoNewline -ForegroundColor Magenta

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # relocate cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

        # Getting user $input
        $key = $null
        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")

        # if answer is part of the accepted value, we echo the desc and move next. Else... Lurch?
        if ($key.character -match $IdRegexFL -and $key.Character -ne 13) {
            $DomainDFL = [String]"$($key.character)"
            $DbgLog += @("Key '$($key.character)' Pressed. DomainDFL will be $($DomainDFL)")
            if ($DomainDFL -eq "0") { 
                $DomainDFL = "10"
                $DbgLog += @('Domain DFL rewriten from 0 to 10')
            }
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.Id -eq $DomainDFL}).Desc) -ForegroundColor Green
            $isKO = $false
        }
        elseif ($key.VirtualKeyCode -eq 13) {
            $DbgLog += @("Enter Pressed. DomainDFL is $DomainDFL")
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $(($ScriptSettings.Settings.FunctionalLevel.Definition | Where-Object { $_.Id -eq $DomainDFL}).Desc) -ForegroundColor Green
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

    # Write to XML
    $PreviousChoices.Configuration.Domain.FunctionalLevel = $DomainDFL

    #########################
    # QUESTION: SYSVOL PATH #
    #########################
    # Enquiring for the new name
    ## Calling Lurch from Adam's family...
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadInputFormat).Split(';'))

    ## Getting default value, or previous one
    if ([String]::IsNullOrEmpty($DomainSYS)) {
        $DomainSYS = "$($Env:WinDir)\SYSVOL"
    }

    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='014']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr

    ## Input time
    ## Get current cursor position and create the Blanco String
    $StringCleanSet = " "
    $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
    for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
        $StringCleanSet += " " 
    }

    ## Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition

    ## Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $DomainSYS -NoNewline -ForegroundColor Magenta

    ## Regex validating that the new name is valid
    $Regex = '^[a-zA-Z][:][\\][\w\\\-]*[\w]$'

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # relocate cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

        # Getting user $input
        [string]$answer = read-host

        # if $answer is null, then we use the default choice
        if ([String]::IsNullOrEmpty($answer)) {
            [string]$answer = $DomainSYS
        }

        # if answer is not null, we ensure that the regex for domain is matched
        if (-not([String]::IsNullOrEmpty($answer))) {
            switch ($answer -match $Regex) {
                $true {
                    $DomainSYS = [string]$answer
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $DomainSYS -ForegroundColor Green
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

    # Write to XML
    $PreviousChoices.Configuration.Domain.sysvolPath = $DomainSYS
    $DbgLog += @("Domain SYSVOL: $domainSYS")

    #######################
    # QUESTION: NTDS PATH #
    #######################
    # Enquiring for the new name
    ## Calling Lurch from Adam's family...
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadInputFormat).Split(';'))

    ## Getting default value, or previous one
    if ([String]::IsNullOrEmpty($DomainNTD)) {
        $DomainNTD = "$($Env:WinDir)\NTDS"
    }

    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='015']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr

    ## Input time
    ## Get current cursor position and create the Blanco String
    $StringCleanSet = " "
    $MaxStringLength = ($LurchMood | Measure-Object -Property Length -Maximum).Maximum
    for ($i=2 ; $i -le $MaxStringLength ; $i++) { 
        $StringCleanSet += " " 
    }

    ## Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition

    ## Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $DomainNTD -NoNewline -ForegroundColor Magenta

    ## Regex validating that the new name is valid
    $Regex = '^[a-zA-Z][:][\\][\w\\\-]*[\w]$'

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        # relocate cursor
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y

        # Getting user $input
        [string]$answer = read-host

        # if $answer is null, then we use the default choice
        if ([String]::IsNullOrEmpty($answer)) {
            [string]$answer = $DomainNTD
        }

        # if answer is not null, we ensure that the regex for domain is matched
        if (-not([String]::IsNullOrEmpty($answer))) {
            switch ($answer -match $Regex) {
                $true {
                    $DomainNTD = $answer
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $StringCleanSet -NoNewline
                    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                    Write-Host $DomainNTD -ForegroundColor Green
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

    # Write to XML
    $PreviousChoices.Configuration.Domain.NtdsPath = $DomainNTD
    $DbgLog += @("Domain NTDS: $domainNTD")

    # End logging
    Write-toEventLog $ExitLevel $DbgLog | Out-Null

    # Return result
    return $PreviousChoices
}