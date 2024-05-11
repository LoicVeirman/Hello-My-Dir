<#
    THIS MODULE CONTAINS FUNCTIONS TO HANDLE SCREEN OUTPUT.
#>

Function Format-ScreenText {
    <#
        .SYNOPSIS
        Split a text to multiple lines with no cutted word on screen.

        .DESCRIPTION
        When a text is displayed on screen, the text may be badly formated on screen and words may be cut, making text uneasy to read.
        This function return an array containing text line having a total length lower that the screen width display.

        .PARAMETER Text
        The text to be formated. Can be an array or a string.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/11 -- Script creation.
    #>
    [CmdletBinding()]
    param (
        [Parameter(mandatory,Position=0)]
        [Array]
        $Text
    )

    # No logging for this function.
    # Getting window data
    $console = $host.ui.rawui
    $ConsoleSize = $console.WindowSize
    $ConsoleWidth = $ConsoleSize.Width

    # Fire-up result array
    $Result = @()

    foreach ($line in $Text) {
        # We split $line to words by using " " as spearator.
        $WordList = $line -split ' '

        # We add word up to the max width minus 2.
        $TmpLine = $null
        foreach ($word in $WordList) {
            # Check if, by adding a word, the TmpLine length is greater than the widh...
            if (($TmpLine.length + $word.length) -gt $ConsoleWidth - 2) {
                # Then we add the TmpLine to the result array, null it and start a new line.
                $Result += $TmpLine
                $TmpLine = $word
            }
            Else {
                # We add the word to TmpLine.
                if ($TmpLine.length -eq 0) {
                    # Use case: first line, first word...
                    $TmpLine = $word
                }
                Else {
                    $TmpLine += " $($word)"
                }
            }
        }
        # End of line, we move to a new one.
        $Result += $TmpLine
    }

    # return result
    return $Result
}

Function New-ModuleScreeningXmlFile {
    <#
        .SYNOPSIS
        Will generate a default Module-Screening.xml file.

        .DESCRIPTION
        Will ensure our functions will works if the file Module-Screening.xml is badly formatted or missing.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/11 -- Script creation.
    #>
    Param()

    # No Logging
    # First, dealing with a badly formated xml file.
    # We backup it ONLY if a backup file is not already present. Else, we delete the file.
    if ((Test-Path .\Modules\Module-Screening\Module-Screening.xml) -and -not ((Test-Path .\Modules\Module-Screening\Module-Screening.xml.bak))) {
        Rename-Item (Resolve-Path .\Modules\Module-Screening\Module-Screening.xml).Path -NewName (((Resolve-Path .\Modules\Module-Screening\Module-Screening.xml).Path).Replace('xml','bak'))
    } elseif ((Test-Path .\Modules\Module-Screening\Module-Screening.xml)) {
        Remove-Item (Resolve-Path .\Modules\Module-Screening\Module-Screening.xml).Path
    }

    # Second, we create our new file.
    $defaultXml = New-XmlContent -XmlFile .\Modules\Module-Screening\Module-Screening.xml

    # Third, we add our values.
    $defaultXml.WriteStartElement('Settings')
        $defaultXml.WriteStartElement('Format')
            $defaultXml.WriteStartElement('Title')
                $defaultXml.WriteAttributeString('ForegroundColor','Yellow')
                $defaultXml.WriteAttributeString('BackgroundColor','')
                $defaultXml.WriteAttributeString('Uppercase','Yes')
                $defaultXml.WriteAttributeString('Frame','*')
            $defaultXml.WriteEndElement()
            $defaultXml.WriteStartElement('Text')
                $defaultXml.WriteAttributeString('ForegroundColor','Gray')
                $defaultXml.WriteAttributeString('BackgroundColor','')
                $defaultXml.WriteAttributeString('Uppercase','No')
                $defaultXml.WriteAttributeString('Frame','|')
            $defaultXml.WriteEndElement()
            $defaultXml.WriteStartElement('Input')
                $defaultXml.WriteAttributeString('ForegroundColor','Cyan')
                $defaultXml.WriteAttributeString('BackgroundColor','')
                $defaultXml.WriteAttributeString('Uppercase','No')
                $defaultXml.WriteAttributeString('Frame','')
            $defaultXml.WriteEndElement()
            $defaultXml.WriteStartElement('Offer')
                $defaultXml.WriteAttributeString('ForegroundColor','DarkGray')
                $defaultXml.WriteAttributeString('BackgroundColor','')
                $defaultXml.WriteAttributeString('Uppercase','No')
                $defaultXml.WriteAttributeString('Frame','')
            $defaultXml.WriteEndElement()
            $defaultXml.WriteStartElement('Dynamic')
                $defaultXml.WriteStartElement('Disable')
                    $defaultXml.WriteAttributeString('Color','DarkGray')
                $defaultXml.WriteEndElement()
                $defaultXml.WriteStartElement('Pending')
                    $defaultXml.WriteAttributeString('Color','Gray')
                $defaultXml.WriteEndElement()
                $defaultXml.WriteStartElement('Running')
                    $defaultXml.WriteAttributeString('Color','Cyan')
                $defaultXml.WriteEndElement()
                $defaultXml.WriteStartElement('Warning')
                    $defaultXml.WriteAttributeString('Color','Yellow')
                $defaultXml.WriteEndElement()
                $defaultXml.WriteStartElement('Failure')
                    $defaultXml.WriteAttributeString('Color','Red')
                $defaultXml.WriteEndElement()
                $defaultXml.WriteStartElement('Success')
                    $defaultXml.WriteAttributeString('Color','Green')
                $defaultXml.WriteEndElement()
            $defaultXml.WriteEndElement()
        $defaultXml.WriteEndElement()
    $defaultXml.WriteEndElement()

    # finaly, we output the result to our files.
    $defaultXml.WriteEndDocument()
    $defaultXml.Flush()
    $defaultXml.Close()
}

Function Write-TitleText {
    <#
        .SYNOPSIS
        Echo a text as a title one.

        .DESCRIPTION
        Simple function to write a title on the screen. 
        This function will rely on custom value from Module-Screening.xml.

        .PARAMETER Text
        A string or array of string that contains the title text.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/11 -- Script creation.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,Position=0)]
        [Array]
        $Text
    )

    # No Logging.
    # Import XML settings data.
    $xmlSettings = Get-XmlContent .\modules\Module-Screening\Module-Screening.Xml

    if (-not ($xmlSettings)) {
        # Load as failed. We create a default one with our own values...
        New-ModuleScreeningXmlFile
        # Then we load it.
        $xmlSettings = Get-XmlContent .\modules\Module-Screening\Module-Screening.Xml
    }

    # Prepare write-host attributes
    $Attributes = @{}
    if ($xmlSettings.Settings.Format.Title.ForegroundColor) {
        $Attributes.Add('ForegroundColor',$xmlSettings.Settings.Format.Title.ForegroundColor)
    } 
    if ($xmlSettings.Settings.Format.Title.BackgroundColor) {
        $Attributes.Add('BackgroundColor',$xmlSettings.Settings.Format.Title.BackgroundColor)
    }

    # Prepare Title Text 
    $TitleText = Format-ScreenText $Text
    foreach ($line in $TitleText) {
        $FinalText += @("$($xmlSettings.Settings.Format.Title.Frame) $Line")
    }

    # Echo title text
    foreach ($line in $FinalText) {
        if ($xmlSettings.Format.Title.Uppercase -eq 'Yes') {
            $line = $line.ToUpper()
        }
        Write-Host $line $Attributes
    }
}