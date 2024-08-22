# Install and import the AzureAD module
Import-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# Define the user
$userPrincipalName = "user@azuread.com" # Replace with the user's UPN

# Get the user's object ID
$user = Get-AzureADUser -ObjectId $userPrincipalName

if ($user) {
    # Get the user's group memberships
    $userGroups = Get-AzureADUserMembership -ObjectId $user.ObjectId | Where-Object { $_.ObjectType -eq "Group" }

    # Create a list to store group details
    $groupList = @()

    # Loop through each group and add details to the list
    foreach ($group in $userGroups) {
        $groupDetails = [PSCustomObject]@{
            GroupName = $group.DisplayName
            GroupId = $group.ObjectId
        }
        $groupList += $groupDetails
    }

    # Define the output CSV file path
    $csvFilePath = "C:\Users\Wsadminmm\Downloads\$userPrincipalName.csv" # Replace with your desired file path

    # Export the group details to a CSV file
    $groupList | Export-Csv -Path $csvFilePath -NoTypeInformation

    Write-Output "The user's group memberships have been exported to $csvFilePath"
} else {
    Write-Output "User not found."
}
