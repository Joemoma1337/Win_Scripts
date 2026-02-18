# Import AD Module
if (!(Get-Module -ListAvailable ActiveDirectory)) {
    Write-Error "The ActiveDirectory module is required. Please install RSAT."
    return
}

# Configuration
$alphaPool = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
$fullPool  = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890=-+_@#"
$totalLength = 30
$inputFile = "SAM_Input.txt"
$outputFile = "Password_Reset_Results.csv"

# Array to store results for CSV export
$results = @()

if (-not (Test-Path $inputFile)) {
    Write-Error "Input file $inputFile not found."
    return
}

$users = Get-Content $inputFile

foreach ($user in $users) {
    $samAccount = $user.Trim()
    if ([string]::IsNullOrWhiteSpace($samAccount)) { continue }

    try {
        # 1. Generate password (starts with letter)
        $firstChar = $alphaPool[(Get-Random -Maximum $alphaPool.Length)]
        $remainingChars = -join ((1..($totalLength - 1)) | ForEach-Object { $fullPool[(Get-Random -Maximum $fullPool.Length)] })
        $newPassword = $firstChar + $remainingChars
        
        # 2. Apply to Active Directory
        $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force
        Set-ADAccountPassword -Identity $samAccount -NewPassword $securePassword -Reset
        #Set-ADUser -Identity $samAccount -ChangePasswordAtLogon $true
        
        $status = "Success"
        Write-Host "Reset successful: $samAccount" -ForegroundColor Green
        #Write-Host "Reset successful: $samAccount : $newPassword" -ForegroundColor Green
    }
    catch {
        $status = "Failed: $($_.Exception.Message)"
        $newPassword = "N/A"
        Write-Warning "Reset failed: $samAccount"
    }

    # 3. Create an object for the audit report
    $results += [PSCustomObject]@{
        Timestamp    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        SAMAccount   = $samAccount
        Action = "Password Reset"
        #NewPassword  = $newPassword
        Status       = $status
    }
}

# 4. Export the collection to CSV
$results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
Write-Host "`nAudit report generated: $outputFile" -ForegroundColor Cyan
