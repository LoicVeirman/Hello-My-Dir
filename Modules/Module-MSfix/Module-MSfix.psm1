Function Repair-NlaSvcOnDC 
{
    <#
        .SYNOPSIS
        Fix Network Profile issue detected as public on DC.

        .DESCRIPTION
        When a DC starts, the NLASVC service is not properly detecting the network profile as Domain and fallback to the Public one.
        This script operate a change to the Network Location Awareness services to ensure that detection will works as expected.

        .NOTES
        Version 1.0.0
        Author  Bastion PEREZ 
    #>
    $serviceName = "nlasvc"
    $desiredDependencies = @("DNS")

    # test if dependency exist
    foreach ($dependency in $desiredDependencies) {
        if (-not (Get-Service $dependency -ErrorAction SilentlyContinue)) {
            return
        }
    }

    # Fetch current dependencies from the registry
    $currentDependencies = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name "DependOnService" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DependOnService

    # Convert current dependencies to an array if they exist
    if ($null -eq $currentDependencies) {
        $currentDependencies = @()
    }
    elseif (-not ($currentDependencies -is [array])) {
        $currentDependencies = @($currentDependencies)
    }

    # Determine which dependencies are missing
    $missingDependencies = $desiredDependencies | Where-Object { $_ -notin $currentDependencies }

    # If there are any missing dependencies, add them
    $asFailed = $false
    if ($missingDependencies.Count -gt 0) {
        $newDependencies = $currentDependencies + $missingDependencies
        Try {
            [void](Set-ItemProperty -Type MultiString -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name "DependOnService" -Value $newDependencies)
        }
        Catch {
            $asFailed = $True
        }
    }

    # return result
    if ($asFailed) {
        $returnCode = "Error"
    }
    Else {
        $returnCode = "Info"
    }
    return $returnCode
}
