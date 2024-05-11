<#
    THIS MODULE CONTAINS FUNCTIONS RELATED TO XML HANDLING (READ, MODIFY, ...)
#>

Function Get-XmlContent {
    <#
        .SYNOPSIS
        Return an XML object to the caller.

        .DESCRIPTION
        Will try to open the specified file, then return it to the caller. If it fails, the function returns a Null object.

        .PARAMETER XmlFile
        Path to the XML file to import. You can use relative or fixed path.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/08 -- Script creation.
    #>

    Param(
        # Xml file path and name
        [Parameter(mandatory, Position=0)]
        [String]
        $XmlFile
    )
    # Module logging requiered, hence we check il we need to load it first.

    # Convert to fixed path
    $xFile = Resolve-Path -Path $XmlFile -ErrorAction SilentlyContinue

    # Check if the xml file is reachable
    Try {
        if (Test-Path $xFile -ErrorAction Stop) {
            # File is present, we will load it
            $xmlData = [xml](Get-Content $xFile -Encoding utf8 -ErrorAction Stop)
        }
        Else {
            # File is unreachable
            $xmlData = $null
        }
    }
    Catch {
        $xmlData = $null
    }

    # Return result
    return $xmlData
}

Function New-XmlContent {
    <#
        .SYNOPSIS
        Create a xml file and return an xml object for data manipulation.

        .DESCRIPTION
        Create a xml file and return an xml object to manipulate its content.

        .PARAMETER XmlFile
        Path to the XML file to import. You can use relative or fixed path.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/10 -- Script creation.
    #>

    Param(
        # Xml file path and name
        [Parameter(mandatory, Position=0)]
        [String]
        $XmlFile
    )
    # Prepare for debug log. Only one entrie in event log for the whole function.
    Test-EventLog
    $DbgLog = @("Function caller: $(((Get-PSCallStack)[1].Command -split '\.')[0])"," ")

    # Test if the file already exists. If so, return a null object.
    Try {
        if (Test-Path (Resolve-Path $XmlFile -ErrorAction Stop)) {
            $DbgLog += "Error: the file could not created as it already exists."
            $DbgType = "ERROR"
            $result = $null
        }
        Else {
            $DbgLog += @("New file creation: $(Resolve-Path $XmlFile)"," ","Encoding: UTF8", "Indent: Yes (tabulation)")
            $DbgType = "INFO"
            
            # Formating XML 
            $xmlSettings = New-Object System.Xml.XmlWriterSettings
            $xmlSettings.Indent = $true
            $xmlSettings.IndentChars = "`t"
            $xmlSettings.Encoding = Encoding.utf8

            # Create the document
            $XmlWriter = [System.XML.XmlWriter]::Create((Resolve-Path $XmlFile), $xmlSettings)

            # Write the XML Decleration and set the XSL
            $xmlWriter.WriteStartDocument()
            $xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")

            # Return the object handler
            $result = $XmlWriter
        }
    }
    Catch {
        $DbgLog += @("New file creation: $($XmlFile)"," ","Encoding: UTF8", "Indent: Yes (tabulation)")
        $DbgType = "INFO"
        
        # Formating XML 
        $xmlSettings = New-Object System.Xml.XmlWriterSettings
        $xmlSettings.Indent = $true
        $xmlSettings.IndentChars = "`t"
        $xmlSettings.Encoding = "utf-8"

        # Create the document
        $XmlWriter = [System.XML.XmlWriter]::Create(($XmlFile), $xmlSettings)

        # Write the XML Decleration and set the XSL
        $xmlWriter.WriteStartDocument()
        $xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")

        # Return the object handler
        $result = $XmlWriter        
    }
    # Writing log
    Write-toEventLog $DbgType $DbgLog

    # Return result
    return $result
}