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
    $myXml.WriteAttributeString('Edition','1.1.2 Quick Fix 002')
    # - Start: Forest
    $myXml.WriteStartElement('Forest')
    $myXml.WriteElementString('Installation','')
    $myXml.WriteElementString('FullName','Hello.My.Dir')
    $myXml.WriteElementString('NetBIOS','HELLO')
    $myXml.WriteElementString('FunctionalLevel','')
    $myXml.WriteElementString('RecycleBin','')
    $myXml.WriteElementString('PAM','')
    $myXml.WriteEndElement()
    # - End: Forest
    # - Start: Domain
    $myXml.WriteStartElement('Domain')
    $myXml.WriteElementString('Type','')
    $myXml.WriteElementString('FullName','Hello.My.Dir')
    $myXml.WriteElementString('NetBIOS','HELLO')
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
    $myXml.WriteElementString('ManagementTools','')
    $myXml.WriteEndElement()
    # - end: WindowsFeatures
    # - Start: ADObjects
    $myXml.WriteStartElement('ADObjects')
    $myXml.WriteStartElement('Users')
    $myXml.WriteElementString('DomainJoin','DLGUSER01')
    $myXml.WriteEndElement()
    $myXml.WriteStartElement('Groups')
    $myXml.WriteElementString('DomainJoin','LS-DLG-DomainJoin-Extended')
    $myXml.WriteEndElement()
    $myXml.WriteEndElement()
    # - end: ADObjects
    # - Start: ConfigFile
    $myXml.WriteStartElement('SetupFile')
    $myXml.WriteStartElement('isCompliant','')
    $myXml.WriteEndElement()
        # - end: ConfigFile
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
        $PreviousChoices,

        # SKU of the operating system
        [Parameter(Mandatory,Position=2)]
        [Int32]
        $OperatingSystemSKU
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
    $ManagementTools = $PreviousChoices.Configuration.Forest.ManagementTools

    $DbgLog += @('Previous choices:',"> Forest Fullname: $ForestDNS","> Forest NetBIOS name: $ForestNtB","> Forest Functional Level: $ForestFFL","> Enable Recycle Bin: $ForestBIN","> Enable PAM: $ForestPAM",' ')

    #############################
    # QUESTION: FOREST DNS NAME #
    #############################
    ## Fist, check if the host is member of a domain. If so, the domain will be used as 
    if ((Get-WmiObject win32_computersystem).partofdomain -eq $true -and $ForestDNS -ne '' -and $null -ne $ForestDNS) {
            # Set the value as default root domain name
            $ForestDNS = (Get-WmiObject win32_computersystem).domain
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

    ##############################
    # QUESTION: MANAGEMENT TOOLS #
    ##############################
    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='006']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
    
    ## Yes/No time
    ### Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition

    ### Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $ManagementTools -NoNewline -ForegroundColor Magenta

    ### Querying input: waiting for Y,N or ENTER.
    $isKO = $True
    While ($isKO)
    {
        ## Reading key press
        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")
        ## Analyzing key pressed
        ## Pressed ENTER
        if ($key.VirtualKeyCode -eq 13) {
            if ([String]::IsNullOrEmpty($ManagementTools)) {
                # If OperatingSystemSKU is Core then set default to No else Yes
                If ($OperatingSystemSKU -in @("12","13","14","29","39","40","41","43","44","45","46","63","147","148")) {
                    $ManagementTools = "No"
                } Else {
                    $ManagementTools = "Yes"
                }
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $StringCleanSet -NoNewline
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $ManagementTools -ForegroundColor Green
                $isKO = $false
            }
            Else {
                if ($ManagementTools -eq 'No') { $color = 'Red' } Else { $color = 'Green' }
                $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
                Write-Host $ManagementTools -ForegroundColor $color
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
            $ManagementTools = "Yes"
            $isKO = $false
        }
        ## Pressed N or N
        elseif ($key.VirtualKeyCode -eq 78) {
            # Is No
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host "No" -ForegroundColor Red
            $ManagementTools = "No"
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
    $PreviousChoices.Configuration.WindowsFeatures.ManagementTools = $ManagementTools

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

    #region INIT
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
    $DomJoinGr = $PreviousChoices.Configuration.ADObjects.Groups.DomainJoin
    $DomJoinUr = $PreviousChoices.Configuration.ADObjects.Users.DomainJoin

    $DbgLog += @('Previous choices:',"> Domain Type: $domainTYP","> Domain Fullname: $domainDNS","> Domain NetBIOS name: $DomainNtB","> Domain Functional Level: $DomainDFL")    
    $DbgLog += @("> Domain Join Group: $domJoinGr","> Domain Join User: $domJoinUr",' ')    
    #endregion
    # Loading Script Settings
    $ScriptSettings = Get-XmlContent .\Configuration\ScriptSettings.xml

    #region DOMAIN TYPE
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
    #endregion
    ## Writing result to XML
    $PreviousChoices.Configuration.Domain.Type = $DomainTYP

    #region DOMAIN FQDN
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
    #endregion
    ## Writing result to XML
    $PreviousChoices.Configuration.Domain.FullName = $DomainDNS

    #region DOMAIN NETBIOS NAME
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
    #endregion
    ## Writing result to XML
    $PreviousChoices.Configuration.Domain.NetBIOS = $DomainNtB

    #region DOMAIN FUNCTIONAL LEVEL
    #####################################
    # QUESTION: DOMAIN FUNCTIONAL LEVEL #
    #####################################
    # Enquiring for the new name
    ## Calling Lurch from Adam's family...
    $LurchMood = @(($ScriptSettings.Settings.Lurch.BadKeyPress).Split(';'))

    # Regex computing
    $OSCaption = (gwmi Win32_OperatingSystem).Caption
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
        if ($key.character -match $IdRegexFL -and $key.VirtualKeyCode -ne 13) {
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
    #endregion
    # Write to XML
    $PreviousChoices.Configuration.Domain.FunctionalLevel = $DomainDFL

    #region SYSVOL PATH
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
    #endregion
    # Write to XML
    $PreviousChoices.Configuration.Domain.sysvolPath = $DomainSYS
    $DbgLog += @("Domain SYSVOL: $domainSYS")

    #region NTDS PATH
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
    #endregion
    # Write to XML
    $PreviousChoices.Configuration.Domain.NtdsPath = $DomainNTD
    $DbgLog += @("Domain NTDS: $domainNTD")

    #region DELEG DOMAIN JOIN
    ########################################
    # QUESTION: DOMAIN JOIN USER AND GROUP #
    ########################################
    # Enquiring for the new service account
    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='016']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
    ## Input time
    $StringCleanSet = "                     "
    ## Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition
    ## Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $DomJoinUr -NoNewline -ForegroundColor Magenta
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
            [string]$answer = $DomJoinUr
        }
        # if answer is not null, we ensure that the regex for domain is matched
        if (-not([String]::IsNullOrEmpty($answer))) {
            $DomJoinUr = $answer
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $DomJoinUr -ForegroundColor Green
            $isKO = $false
        }
    }
    # Enquiring for the new delegation group
    ## Display question 
    $toDisplayXml = Select-Xml $ScriptSettings -XPath "//Text[@ID='017']" | Select-Object -ExpandProperty Node
    $toDisplayArr = @($toDisplayXml.Line1)
    $toDisplayArr += $toDisplayXml.Line2
    Write-UserChoice $toDisplayArr
    ## Input time
    $StringCleanSet = "                     "
    ## Getting cursor position for relocation
    $CursorPosition = $Host.UI.RawUI.CursorPosition
    ## Writing default previous choice (will be used if RETURN is pressed)
    Write-Host $DomJoinGr -NoNewline -ForegroundColor Magenta
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
            [string]$answer = $DomJoinGr
        }
        # if answer is not null, we ensure that the regex for domain is matched
        if (-not([String]::IsNullOrEmpty($answer))) {
            $DomJoinGr = $answer
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $StringCleanSet -NoNewline
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $CursorPosition.X, $CursorPosition.Y
            Write-Host $DomJoinGr -ForegroundColor Green
            $isKO = $false
        }
    }    
    #endregion

    # Write to XML
    $PreviousChoices.Configuration.ADObjects.Groups.DomainJoin = $DomJoinGr
    $PreviousChoices.Configuration.ADObjects.Users.DomainJoin = $DomJoinUr
    $DbgLog += @("Domain Join User: $domJoinUr","Domain Join Group: $DomJoinGr")

    # End logging
    Write-toEventLog $ExitLevel $DbgLog | Out-Null

    # Return result
    return $PreviousChoices
}

Function Update-HmDRunSetupXml {
    <#
        .SYNOPSIS
        Update an existing runSetup.xml file.

        .DESCRIPTION
        The file runSetup.xml is a prerequesite for the script to run. This function updates one with no previous value set.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/06/29 -- Script creation.
    #>
    Param()

    # No logging.
    try 
    {
        # Create xml file
        $myXml = New-XmlContent -XmlFile .\Configuration\RunSetupNew.xml
        $pvXml = Get-XmlContent -XmlFile .\Configuration\RunSetup.xml

        # Add content
        # - Start: Configuration
        $myXml.WriteStartElement('Configuration')
        $myXml.WriteAttributeString('Edition','1.1.2 Quick fix 002')
        # - Start: Forest
        $myXml.WriteStartElement('Forest')
        $myXml.WriteElementString('Installation',$pvXml.Configuration.Forest.Installation)
        $myXml.WriteElementString('FullName',$pvXml.Configuration.Forest.Fullname)
        $myXml.WriteElementString('NetBIOS',$pvXml.Configuration.Forest.NetBios)
        $myXml.WriteElementString('FunctionalLevel',$pvXml.Configuration.Forest.FunctionalLevel)
        $myXml.WriteElementString('RecycleBin',$pvXml.Configuration.Forest.RecycleBin)
        $myXml.WriteElementString('PAM',$pvXml.Configuration.Forest.PAM)
        $myXml.WriteEndElement()
        # - End: Forest
        # - Start: Domain
        $myXml.WriteStartElement('Domain')
        $myXml.WriteElementString('Type',$pvXml.Configuration.Domain.Type)
        $myXml.WriteElementString('FullName',$pvXml.Configuration.Domain.Fullname)
        $myXml.WriteElementString('NetBIOS',$pvXml.Configuration.Domain.NetBios)
        $myXml.WriteElementString('FunctionalLevel',$pvXml.Configuration.Domain.FunctionalLevel)
        $myXml.WriteElementString('SysvolPath',$pvXml.Configuration.Domain.sysvolPath)
        $myXml.WriteElementString('NtdsPath',$pvXml.Configuration.Domain.ntdsPath)
        $myXml.WriteEndElement()
        # - End: Domain
        # - Start: WindowsFeatures
        $myXml.WriteStartElement('WindowsFeatures')
        $myXml.WriteElementString('AD-Domain-Services',$pvXml.Configuration.WindowsFeatures."AD-Domain-Services")
        $myXml.WriteElementString('RSAT-AD-Tools',$pvXml.Configuration.WindowsFeatures."RSAT-AD-Tools")
        $myXml.WriteElementString('RSAT-DNS-Server',$pvXml.Configuration.WindowsFeatures."RSAT-DNS-Server")
        $myXml.WriteElementString('RSAT-DFS-Mgmt-Con',$pvXml.Configuration.WindowsFeatures."RSAT-DFS-Mgmt-Con")
        $myXml.WriteElementString('GPMC',$pvXml.Configuration.WindowsFeatures.GPMC)
        $myXml.WriteElementString('ManagementTools',$pvXml.Configuration.WindowsFeatures.ManagementTools)
        $myXml.WriteEndElement()
        # - end: WindowsFeatures
        # - Start: ADObjects
        $myXml.WriteStartElement('ADObjects')
        $myXml.WriteStartElement('Users')
        $myXml.WriteElementString('DomainJoin','DLGUSER01')
        $myXml.WriteEndElement()
        $myXml.WriteStartElement('Groups')
        $myXml.WriteElementString('DomainJoin','LS-DLG-DomainJoin-Extended')
        $myXml.WriteEndElement()
        $myXml.WriteEndElement()
        # - end: ADObjects
        # - End: Configuration
        $myXml.WriteEndElement()

        # Closing document
        $MyXml.WriteEndDocument()
        $myXml.Flush()
        $myXml.Close()

        # Backing-up old xml and renaming new one
        try 
        {
            Rename-Item .\Configuration\RunSetup.xml RunSetup.xml.bak -ErrorAction Stop
        }
        catch 
        {
            [void](Remove-Item .\Configuration\RunSetup.xml.bak -Force -Confirm:$false)
            Start-Sleep -Milliseconds 15
            Rename-Item .\Configuration\RunSetup.xml RunSetup.xml.bak
        }
        
        Rename-Item .\Configuration\RunSetupNew.xml RunSetup.xml -Force

        # Result
        $arrayResult = @{Code="success";Message="The file RunSetup.xml has been successfully updated."}
    }
    Catch 
    {
        $arrayResult = @{Code="error";Message="Failed to update the RunSetup.xml file. Error: $($_.ToString())"}
    }

    # return result
    return $arrayResult
}

function Get-HmDValidates {
   <#
        .SYNOPSIS
        Validates data in the runSetup.xml file.

        .DESCRIPTION
        This function loads the runSetup.xml file and validates the data under the Forest and Domain nodes.
        It checks if the FullName values match a specified regex pattern and outputs a custom object with
        the FullName, its value, and the match result.

        .NOTES
        Version: 01.000.000 -- Jérôme Bezet-Torres (JM2K69)
        History: 2024/10/17 -- Script creation.

        .PARAMETER None
        This function does not take any parameters.

        .OUTPUTS
        PSCustomObject
        The function outputs a custom object with the following properties:
        - FullName: The name of the node (Forest or Domain).
        - Value: The FullName value from the XML node.
        - Match: The result of the regex match ("ok" or "not ok").

        .EXAMPLE
        PS> Get-HmDValidates
        This command validates the data in the runSetup.xml file and outputs the validation results.
   #>

    param (
    )

    # Load the XML file
    $xmlRunSetup = Get-XmlContent .\Configuration\RunSetup.xml -ErrorAction SilentlyContinue


    # Define regular expressions for validation
    $domainRegex = '^(?=.{1,255}$)(?:(?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,6}$'
    $yesNoRegex = '^(Yes|No)$'
    $functionalLevelRegex = '^\d+$'

    # Create PowerShell objects to store the results Result contains the result of the validation for two nodes: Forest and Domain
    $result = [PSCustomObject]@{
        Forest = [PSCustomObject]@{
            Installation = $null
            FullName = $null
            NetBIOS = $null
            FunctionalLevel = $null
            RecycleBin = $null
            PAM = $null
            IsValidInstallation = $false
            IsValidFullName = $false
            IsValidNetBIOS = $false
            IsValidFunctionalLevel = $false
            IsValidRecycleBin = $false
            IsValidPAM = $false
        }
        Domain = [PSCustomObject]@{
            Type = $null
            FullName = $null
            NetBIOS = $null
            FunctionalLevel = $null
            SysvolPath = $null
            NtdsPath = $null
            IsValidType = $false
            IsValidFullName = $false
            IsValidNetBIOS = $false
            IsValidFunctionalLevel = $false
            IsValidSysvolPath = $false
            IsValidNtdsPath = $false
        }
    }

    $hasInvalidValue = $false

    # Validate elements under Forest
    $forest = $xmlRunSetup.Configuration.Forest
    $result.Forest.Installation = $forest.Installation
    $result.Forest.IsValidInstallation = $forest.Installation -match $yesNoRegex
    if (-not $result.Forest.IsValidInstallation) { $hasInvalidValue = $true }

    $result.Forest.FullName = $forest.FullName
    $result.Forest.IsValidFullName = $forest.FullName -match $domainRegex
    if ($result.Forest.IsValidFullName -ne $true) { $hasInvalidValue = $true }

    $result.Forest.NetBIOS = $forest.NetBIOS
    $result.Forest.IsValidNetBIOS = $null -ne $forest.NetBIOS
    if (-not $result.Forest.IsValidNetBIOS) { $hasInvalidValue = $true }

    $result.Forest.FunctionalLevel = $forest.FunctionalLevel
    $result.Forest.IsValidFunctionalLevel = $forest.FunctionalLevel -match $functionalLevelRegex
    if (-not $result.Forest.IsValidFunctionalLevel) { $hasInvalidValue = $true }

    $result.Forest.RecycleBin = $forest.RecycleBin
    $result.Forest.IsValidRecycleBin = $forest.RecycleBin -match $yesNoRegex
    if (-not $result.Forest.IsValidRecycleBin) { $hasInvalidValue = $true }

    $result.Forest.PAM = $forest.PAM
    $result.Forest.IsValidPAM = $forest.PAM -match $yesNoRegex
    if (-not $result.Forest.IsValidPAM) { $hasInvalidValue = $true }

    # Validate elements under Domain
    $domain = $xmlRunSetup.Configuration.Domain
    $result.Domain.Type = $domain.Type
    $result.Domain.IsValidType = $null -ne $domain.Type
    if (-not $result.Domain.IsValidType) { $hasInvalidValue = $true }

    $result.Domain.FullName = $domain.FullName
    $result.Domain.IsValidFullName = $domain.FullName -match $domainRegex
    if ($result.Domain.IsValidFullName -ne $true) { $hasInvalidValue = $true }

    $result.Domain.NetBIOS = $domain.NetBIOS
    $result.Domain.IsValidNetBIOS = $null -ne $domain.NetBIOS
    if (-not $result.Domain.IsValidNetBIOS) { $hasInvalidValue = $true }

    $result.Domain.FunctionalLevel = $domain.FunctionalLevel
    $result.Domain.IsValidFunctionalLevel = $domain.FunctionalLevel -match $functionalLevelRegex
    if (-not $result.Domain.IsValidFunctionalLevel) { $hasInvalidValue = $true }

    $result.Domain.SysvolPath = $domain.SysvolPath
    $result.Domain.IsValidSysvolPath = $null -ne $domain.SysvolPath
    if (-not $result.Domain.IsValidSysvolPath) { $hasInvalidValue = $true }

    $result.Domain.NtdsPath = $domain.NtdsPath
    $result.Domain.IsValidNtdsPath = $null -ne $domain.NtdsPath
    if (-not $result.Domain.IsValidNtdsPath) { $hasInvalidValue = $true }

    if ($hasInvalidValue) {

        Write-Host "`nRunSetup.xml is not in the expected format!" -ForegroundColor Red
        Write-Host  "Error message...: The file RunSetup.xml contain invalid data" -ForegroundColor Yellow
        Write-Host  "Advised solution: run the script with the parameter '-UpdateConfigFile'.`n"-ForegroundColor Yellow
        
        # Output the results to the screen
        Write-Output $result.Forest | Format-List
        Write-Output $result.Domain | Format-List

        $arrayScriptLog += @(' ', "RunSetup.xml contain invalid data", "Error:$($result.Forest | Format-Table)")
        $arrayScriptLog += @(' ', "RunSetup.xml contain invalid data", "Error:$($result.Domain | Format-Table)")

        # Log the error to the event log
        Write-toEventLog ERROR $arrayScriptLog

    } else {
        return $null
    }
}

