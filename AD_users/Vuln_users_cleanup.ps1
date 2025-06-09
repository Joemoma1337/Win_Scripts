# Specify the OU path where users will be deleted
$OUPath = "OU=vulnerable,DC=lab,DC=local"

# Get all users in the specified OU
$users = Get-ADUser -Filter * -SearchBase $OUPath

# Loop through each user and delete them
foreach ($user in $users) {
    Remove-ADUser -Identity $user -Confirm:$false
    Write-Host "Deleted user: $($user.SamAccountName)"
}

Write-Host "All users in the 'vulnerable' OU have been deleted."
