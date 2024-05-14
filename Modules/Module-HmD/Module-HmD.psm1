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

    # Question party! Each time a 'OlfForestXXX' will be empty, a defaut choice will be offered.
    ## 
    # End logging
    Write-toEventLog $ExitLevel $DbgLog
}