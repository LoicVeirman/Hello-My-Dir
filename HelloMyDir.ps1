<#
    .SYNOPSIS
    This is the main script of the project "Hello my Dir!".

    .COMPONENT
    PowerShell v5 minimum.

    .DESCRIPTION
    This is the main script to execute the project "Hello my Dir!". This project is intended to ease in building a secure active directory from scratch and maintain it afteward.

    .EXAMPLE
    .\HelloMyDir.ps1

    .NOTES
    Version: 01.00.000
     Author: Loic VEIRMAN (MSSec)
    Details: Script creation
#>
Param()

function test-zelogmachine {
	$test = test-EventLog
	
	$msg = @()
	$msg += "Ligne 1"
	$msg += "Ligne 2"
	$msg += "Ligne 3"
	
	Write-ToEventLog INFO $msg -errorAction SilentlyContinue
}

$testouille = Test-EventLog

test-zelogmachine