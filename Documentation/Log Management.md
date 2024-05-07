# LOG MANAGEMENT
### How to manage loging with your scripts
Logs are part of any code. This papersheet explains how logs should be used in your own repository.

## Do...
* You *do* store your logs in the Event viewer.
* You *do* store your logs in your own log file (.evt or .evtx).
* You *do* use your unique log sources that should **never** be used in another log.

## How you can achieve the three Do rules?
This script uses fonctions from the module HMD-Engine.psm1:
> **Write-toEventLog**: this function write your log text in your log file. 
>
> **Test-EventLog**: this function ensure that your log file and log source exists.

The functions *Write-DebugLog* and *Export-DebugLog* are only use to maintain a loging for the two other functions.

## How the functions works
The function to write and test event log works the same way: the event log file name will always be read from the *ScriptSettings.xml* file (always present in the *.\Configuration* folder). This file contains a specific section:
```
<Settings>
    <!-- Logs are stored in the Event Viewer -->
    <Logging Name="HelloMyDir" Prefix="HmD_" />
</Settings>
```
The logging balise contains two important value used by the function:
1. *Name*: this is the name of your log file. It should be unique, but if it already exists, then it will use it.
2. *Prefix*: This is a unique value that will be added to your script / function name to generate a unique Source ID.

When you use the log function, those ones will always use the PStack Caller name as source name (so you don't have to worry about your source name. You also will easily filter your event log to troubleshot a function). Example:
```
1. The script "myScript.ps1" add log                    [ Write to Logname: HelloMyDir - Source: HmD_myScript   ]
2. The script call a function "myFunction"              [ Write to Logname: HelloMyDir - Source: HmD_MyFunction ]
3. The function now run another function "otherFunc"    [ Write to Logname: HelloMyDir - Source: HmD_otherFunc  ]
```

## How to use the log functions
There is a two-step process to include in each of your script / function:
1. First, you should call the *Test-EventLog* to ensure the log file and the source exists.
2. Second, you use the function *Write-ToEventLog* to add your event to the log file.

*Test-EventLog* doesn't needs any parameter: the logname is read from the xml configuration file and the log source is a mix of the xml configuration file (prefix) and the script or function using it (psStack caller). The function returns $True if everything went fine (logfile and source are ready to be used), or $False if an error is met. Don't forget to handle this error in your code.

*Write-ToEventLog* needs two parameters:
1. *Event Type*: should be INFO, WARNING or ERROR, depending on type of message you want to log.
2. *Event Message*: This is a text array, so you can prepare all your log trace and send it once you'll get all that things up.

If any issues occurs, an exit code is sent, but you don't need to handle it. Use the parameter **-ErrorAction SilentlyContinue** to manage your code with no error.

Here is a code example:
```
Function Run-Away {
    param()
    # initialize log (logname is '%name%' and source '%prefix%Run-Away')
    $initLog = Test-EventLog

    if (-not ($initlog)) {
        write-warning "The log could not be stored in event viewer! Please review your xml settings."
    }

    # Preparing log text...
    $myTextLog = @("This is a log demo")
    $myTextLog += "What a wonderfull log, isn't it?")
    $myTextLog += "I deserve a medal for this..."

    # Adding log to event log pit
    Write-ToEventLog INFO $myTextLog -ErrorAction SilentlyContinue
}
```
## Support
Contact me through GitHub for any support.