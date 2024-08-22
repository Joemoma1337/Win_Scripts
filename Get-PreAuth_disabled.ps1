# Get all user accounts from Active Directory
$users = Get-ADUser -Filter * -Properties DoesNotRequirePreAuth

# Initialize an array to hold the usernames of accounts where DoesNotRequirePreAuth is true
$usersWithPreAuthDisabled = @()

# Loop through each user and check the DoesNotRequirePreAuth attribute
foreach ($user in $users) {
    if ($user.DoesNotRequirePreAuth -eq $true) {
        # Add the username to the array if DoesNotRequirePreAuth is true
        $usersWithPreAuthDisabled += $user.SamAccountName
    }
}

# Output the usernames of accounts where DoesNotRequirePreAuth is true
Write-Output "Usernames of accounts where DoesNotRequirePreAuth is true:"
$usersWithPreAuthDisabled
