# Define the path to your file containing SAM account names (one per line)
$userFile = "C:\temp\users.txt"

# Define the character set for the unique password
$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_()=+"

# Check if the file exists before proceeding
if (Test-Path $userFile) {
    $samAccounts = Get-Content $userFile

    foreach ($user in $samAccounts) {
        # Generate a unique 32-character password
        $newPassword = -join ((1..32) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

        try {
            # FOR ACTIVE DIRECTORY ACCOUNTS:
            Set-ADAccountPassword -Identity $user -NewPassword (ConvertTo-SecureString $newPassword -AsPlainText -Force) -ErrorAction Stop
            
            # FOR LOCAL ACCOUNTS (Uncomment the line below and comment out the AD line above):
            # $localUser = Get-LocalUser -Name $user
            # $localUser | Set-LocalUser -Password (ConvertTo-SecureString $newPassword -AsPlainText -Force)

            Write-Host "Successfully reset password for: $user" -ForegroundColor Green
            Write-Host "New Password: $newPassword"
        }
        catch {
            Write-Warning "Failed to reset password for $user. Reason: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Error "The file $userFile was not found."
}
