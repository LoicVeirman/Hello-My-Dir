<#
    THIS MODULE CONTAINS FUNCTIONS RELATED TO LOGGING PURPOSE (FILE AND EVENT LOG)
#>
Function Write-toEventLog {
    <#
        .SYNOPSIS
        This function write log to the event viewer.

        .DESCRIPTION
        This function write log to the event viewer and use parameter from ScriptSettings.xml (<Logging />).

        .PARAMETER EventType
        Type of event to report (information,warning or error).

        .PARAMETER EventMsg
        Array with all the text to append to the message.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/02 -- Script creation.
    #>

    [Alias("wev")]
    [CmdletBinding()]
    param ( 
        [Parameter(Position = 0)]
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [AllowNull()]
        [string]$EventType,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullorEmpty()]
        [array]$EventMsg
    )

    # Get psStack Caller Name
    $callStack = Get-PSCallStack
    $EventSrc = ($CallStack[1].Command -split '\.')[0]

    # Fixed value from $EventType
    $EventID = @{'Information' = 0; 'Warning' = 1; 'Error' = 2 }

    # Load xml setting file for configuration data
    Try {
        $xmlSettings = [xml](Get-Content .\Configuration\ScriptSettings.xml -Encoding utf8 -ErrorAction Stop)
    }
    Catch {
        # fatal error.
        Exit 2
    }

    # Initialize Event Data with fixed value (adapt to your script)
    $Prefix = $xmlSettings.Settings.Logging.Prefix
    $EventSrc = "$Prefix$EventSrc"

    # Select adapted information for the event
    if ($null -eq $EventType -or $EventType -eq 'INFO') {
        $EventType = "Information"
    } 

    # Translate array to string
    [String]$Message = ""

    foreach ($input in $EventMsg) {
        $Message += "$($input)`n"
    }

    # Write to EventLog. If it failed, then output to a text file (append mode)
    Try {
        [System.Diagnostics.EventLog]::WriteEntry($EventSrc, $Message, $EventType, $EventID.$EventType)    
    }
    Catch {
        foreach ($line in ($Message -split '`n')) {
            "$(Get-Date 'yyyy-MM-dd;hh:mm:ss');EventType;$Line" | Out-File "$EventSrc.log" -Encoding utf8 -Append
        }
    }
}

Function Test-EventLog {
    <#
        .SYNOPSIS
        Check if the source and the log file are present on this system.

        .DESCRIPTION
        This function will prepare the system event log with the appropriate source.
        The Event Log File name will be retrieved from .\Configuration\config.Xml file: <Logging Name="The Event Log File Name" DefaultSource="MyDefaultSource" />
        The Event Log Source will be the name of the script calling this function (hence, you need to call this code each time you run a function or script).

        This function is the only one to output a debug log in .\Logs\Test-EventLog.dbg

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/02 -- Script creation.
    #>
    [Alias("tev")]
    [CmdletBinding()]
    Param()

    # First, prepare a debug log.
    $DbgFile = '{0}.dbg' -f $MyInvocation.MyCommand
    $DbgMsg = @()

    # Init log
    $DbgMsg += Write-DebugLog -Initialize

    # Get File Name and Default Source to be used on creation (if needed)
    Try {
        $xmlConfig = [xml](Get-Content .\Configuration\ScriptSettings.xml -Encoding utf8 -ErrorAction Stop)
        $DbgMsg += Write-DebugLog INFO ".\Configuration\ScriptSettings.xml loaded successfully."
    }
    Catch {
        # Fatal error: script leaves.
        $DbgMsg += Write-DebugLog ERROR @("Failed to load .\Configuration\ScriptSettings.xml.", "Script exits with code 2")
        $DbgMsg += Write-DebugLog -Conclude
        Export-DebugLog -Target .\Logs\$DbgFile -LogData $DbgMsg       
        return $false
    }

    $LogName = $xmlConfig.Settings.Logging.Name
    $LogSource = "$($xmlConfig.Settings.Logging.Prefix)$(((Get-PSCallStack)[1].Command -split '\.')[0])"

    if ($null -eq $Logname -or $null -eq $LogSource) {
        # Failed: one of the value is not properly set, hence the test will fail. Leaving the script.
        $DbgMsg += Write-DebugLog ERROR @("At least one value is null:", "   [LogName]: $($LogName)", "   [LogSource]: $($LogSource)", "Script exits with code 2")
        $DbgMsg += Write-DebugLog -Conclude
        Export-DebugLog -Target .\Logs\$DbgFile -LogData $DbgMsg       
        return $false
    }

    # Test if the Event Log file exist
    if (-not($(Get-EventLog -List | Where-Object { $_.Log -eq $LogName }))) {
        # Create log file
        $DbgMsg += Write-DebugLog WARNING "The log file '$LogName' does not exists."
        Try {
            [System.Diagnostics.EventLog]::CreateEventSource($($xmlConfig.Settings.Logging.Prefix), $LogName)
            $DbgMsg += Write-DebugLog INFO "The log file '$LogName' has been created successfully."
        } 
        Catch {
            # Failed: could not create the file. Leaving the script.
            $DbgMsg += Write-DebugLog ERROR @("Could not create the log file $($LogName)", "Script exits with code 2")
            $DbgMsg += Write-DebugLog -Conclude
            Export-DebugLog -Target .\Logs\$DbgFile -LogData $DbgMsg       
            return $false
        }
    }
    Else {
        # Log exists
        $DbgMsg += Write-DebugLog INFO "The log file '$LogName' already exists."
    }

    # Test if the event source exist in the event log
    if ([System.Diagnostics.EventLog]::SourceExists($LogSource)) {
        # The source exists, we however need to ensure that it is linked to our log
        if (-not([System.Diagnostics.EventLog]::LogNameFromSourceName($LogSource, '.') -contains $LogName)) {
            # Source not linked to the log, we will link it.
            Try {
                [System.Diagnostics.EventLog]::CreateEventSource($LogSource, $LogName)
                $DbgMsg += Write-DebugLog INFO "The source '$LogSource' is now linked to the log '$LogName'."
            }
            Catch {
                # Failed: could not link the source. Leaving the script.
                $DbgMsg += Write-DebugLog ERROR @("Could not link the source '$LogSource' to the log $($LogName)", "Script exits with code 2")
                $DbgMsg += Write-DebugLog -Conclude
                Export-DebugLog -Target .\Logs\$DbgFile -LogData $DbgMsg       
                return $false                
            }
        }
        Else {
            # Alles gut.
            $DbgMsg += Write-DebugLog INFO "The source '$LogSource' is already linked to the log '$LogName'."
        }
    }
    Else {
        $DbgMsg += Write-DebugLog WARNING "The source $($LogSource) does noy exists in the $($Logname) event log."

        # Trying to add the new source
        Try {
            [System.Diagnostics.EventLog]::CreateEventSource($LogSource, $LogName)
            $DbgMsg += Write-DebugLog INFO "The source '$LogSource' is now linked to the log '$LogName'."
        }
        Catch {
            # Failed: could not link the source. Leaving the script.
            $DbgMsg += Write-DebugLog ERROR @("Could not link the source '$LogSource' to the log $($LogName)", "Script exits with code 2")
            $DbgMsg += Write-DebugLog -Conclude
            Export-DebugLog -Target .\Logs\$DbgFile -LogData $DbgMsg       
            return $false
        }
    }
    
    # End log
    $DbgMsg += Write-DebugLog -Conclude

    # Write log to file.
    Export-DebugLog -Target .\Logs\$DbgFile -LogData $DbgMsg

    # Exit
    return $True
}

Function Write-DebugLog {
    <#
        .SYNOPSIS
        Grab debug text and return it as a formated log text as string.

        .DESCRIPTION
        The function ensure that text log are always formated the same way. Accept array as input (beware of timeStamp that will remain the same).

        .PARAMETER Criticity
        Define the debug text criticity level:
        > information: simple trace to better understand what the script was doing
        > warning....: something appends that is related to the script and will make it do a specific choice for the next step.
        > error......: something went bad and the script did not proceed as expected.

        .PARAMETER DebugLog
        An array with the text to append to the log file.

        .PARAMETER Iinitialize
        Instruct the function to add the START header.
        If specified with the -Conclude parameter, then only Initialize will be used.

        .PARAMETER Conclude
        Instruct the function to add the END footer. 
        If specified with the -Initialize parameter, the Conclude will not be used.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/02 -- Script creation.
    #>
    [Alias("wdb")]
    [CmdletBinding(DefaultParameterSetName = 'ADDLOG')]
    Param(
        [Parameter(ParameterSetName = 'ADDLOG')]
        [Parameter(Position = 0)]
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [ValidateNotNullorEmpty()]
        [String]
        $Criticity,

        [Parameter(ParameterSetName = 'ADDLOG')]
        [Parameter(Position = 1)]
        [ValidateNotNullorEmpty()]
        [Array]
        $DebugLog,

        [Parameter(ParameterSetName = 'HEARDER')]
        [Parameter(Position = 2)]
        [ValidateNotNullorEmpty()]
        [Switch]
        $Initialize,

        [Parameter(ParameterSetName = 'FOOTER')]
        [Parameter(Position = 3)]
        [ValidateNotNullorEmpty()]
        [Switch]
        $Conclude
    )
    # Catching timestamp
    $timeStamp = Get-Date -Format 'yyyy/MM/dd  hh:mm:ss  '

    # Use case 1: add a header (START)
    If ($Initialize) {
        $result = @()
        $result += "$($timeStamp)#####"
        $result += "$($timeStamp)##### SCRIPT START"
        $result += "$($timeStamp)#####"
    }

    # Use case 2: add a footer (END)
    if ($Conclude -and -not($Initialize)) {
        $result = @()
        $result += "$($timeStamp)#####"
        $result += "$($timeStamp)##### SCRIPT END"
        $result += "$($timeStamp)#####"
        $result += "$($timeStamp)"
    }
    
    # Use case 3: append log.
    if (-not($Initialize -or $Conclude)) {
        # Initialize result
        $result = @()

        # Translating Criticity
        switch ($Criticity) {
            'INFO' { $Crit = ' INF ' }
            'WARNING' { $Crit = ' WNG ' }
            'CRITICITY' { $Crit = ' ERR ' }
        }

        # Translating text
        foreach ($logLine in $DebugLog) {
            $result += "$($timeStamp)$($Crit)$($logLine)"
        }
    }

    # Sending back result.
    return $result
}

Function Export-DebugLog {
    <#
        .SYNOPSIS
        Write a debug log to a text file.

        .DESCRIPTION
        Write a debug log to a file and ensure that the file is no more that 500 lines.

        .PARAMETER Target
        The path and name were to write the file.

        .PARAMETER LogData
        The data to append to the file.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/02 -- Script creation.
    #>
    [Alias("edb")]
    Param(
        [Parameter(mandatory, position = 0)]
        [System.IO.FileInfo]
        $Target,

        [Parameter(Mandatory, position = 1)]
        [array]
        $LogData
    )

    # Append new lines
    $LogData | Out-File $Target -Append

    # Keep only 1 000 lines max.
    $RotateLog = Get-Content $Target -Tail 1000
    $RotateLog | Out-File $Target -Force
}

#Export-ModuleMember -Function Write-toEventLog,Write-DebugLog,Test-EventLog,Export-DebugLog