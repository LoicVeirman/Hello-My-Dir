<#
    THIS MODULE CONTAINS FUNCTIONS RELATED TO PASSWORD MANAGEMENT
#>
Function New-RandomComplexPasword {
    <#
        .SYNOPSIS
        Generate a random and complex password. 

        .DESCRIPTION
        Generate a complex password long as specified by the Length parameter. If AsClearText is used, then the password is returned in clear text. Else it will be cyphered.

        .PARAMETER Length
        Length size of the password. When not used, the password length will be fixed to 12.

        .PARAMETER AsClearText
        When used, ask the function to not cypher the password.

        .NOTES
        Version: 01.000.000 -- Loic VEIRMAN (MSSec)
        History: 2024/05/10 -- Script creation.
    #>

    Param(
        # Password Length
        [Parameter(mandatory=$False)]
        [int]
        $Length,

        # Force clear text
        [Parameter(Mandatory=$false)]
        [Switch]
        $AsClearText
    )

    # Init log
    Test-EventLog
    $DbgLog = @()
    $DbgLog = @("GENERATE NEW COMPLEX RANDOM PASSWORD","-----------","Parameter Length: $Length","Parameter AsClearText: $AsClearText"," ")

    # Ensure a password length is set.
    if (-not($Length)) {
        # Enforce password length to 12
        [int]$Length = 12
        $DbgLog += "Password Length enforced to 12 characters (default value)."
    }

    # Generate password
    $randomMiddle = [int]($Length / 2)
    
    $minSpecial = 1
    $minDigits = 1
    $minChars = 1
    
    $Special = '"`''#%&,:;<>=@{}~$()*+/\?[]^|'
    $Digits = '0123456789'
    $Chars = 'AZERTYUIOPQSDFGHJKLMWXCVBNazertyuiopqsdfghjklmwxcvbn'
    
    $QuotaSpecial = $minSpecial
    $QuotaDigits = $minDigits
    $QuotaChars = $minChars
    
    $Password = ''

    $DbgLog += "Default settings: at least $($minSpecial *2) special char, $($minDigits * 2) and $($minChars * 2) letters."

    for ($i = 1 ; $i -le $Length ; $i++) {
        # Build allowed char list for this round
        $characters = ""
        if ($QuotaSpecial -gt 0) { 
            $characters += $Special
        }
        if ($QuotaDigits -gt 0) { 
            $characters += $Digits
        }
        if ($QuotaChars -gt 0) { 
            $characters += $Chars
        }
        if ($QuotaSpecial -le 0 -and $QuotaDigits -le 0 -and $QuotaChars -le 0) {
            $characters += "$Special$Digits$Chars"
        }

        $DbgLog += "Round $($i): select from $($characters)"

        # Convert to char array
        $characters = $characters.ToCharArray()

        # randomize the character for this round
        $randomChar = $characters | Get-Random -Count 1

        # decrement counter for the specific char type
        if (Compare-Object $Special.ToCharArray() $randomChar -IncludeEqual -ExcludeDifferent) {
            $QuotaSpecial--
            $DbgLog += "Round $($i): new QuotaSpecial value = $($QuotaSpecial)"
        }
        if (Compare-Object $Digits.ToCharArray() $randomChar -IncludeEqual -ExcludeDifferent) {
            $QuotaDigits--
            $DbgLog += "Round $($i): new QuotaDigits value = $($QuotaDigits)"
        }
        if (Compare-Object $Chars.ToCharArray() $randomChar -IncludeEqual -ExcludeDifferent) {
            $QuotaChars--
            $DbgLog += "Round $($i): new QuotaChars value = $($QuotaChars)"
        }
        # If we have reach the middle of password length, we do reinit quota to initial values
        if ($i -eq $randomMiddle) {
            $QuotaSpecial = $minSpecial
            $QuotaDigits = $minDigits
            $QuotaChars = $minChars
            $DbgLog += "round $($i): Quotas reinitialized."
        }
    
        # Adding character to password
        $Password += $randomChar
        $randomChar = $null
    }

    # Cyphering the password before sending it
    if (-not ($AsClearText)) {
        $Password = ConvertTo-SecureString -AsPlainText $Password -Force
        $DbgLog += "final: password converted to secure string."
    }
    Else {
        $DbgLog += "final: password kept as clear text."
    }

    # Export to log
    Write-ToEventLog INFO $DbgLog

    # Return password
    return $password
}

Export-ModuleMember -Function *