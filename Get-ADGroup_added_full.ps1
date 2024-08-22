# Step 1: Specify the AD Group
$groupName = "Domain Users"

# Step 2: Query the group to get its members
$membersList = Get-ADGroupMember -Identity $groupName | Select-Object -ExpandProperty SamAccountName #comment for targeted
#$membersList = @("test1", "Administrator") #uncomment for targeted by SamAccountName
#$membersList = Get-Content -Path "C:\path\to\your\file.txt" # Reads SamAccountNames from the .txt file

# Output the list of members (for debugging purposes)
#Write-Host "Members of ${groupName}:"
#$membersList

# Step 3: Use the list of users in your script
$group = Get-ADGroup -Filter { Name -eq $groupName }

if ($group -eq $null) {
    Write-Host "Group ${groupName} not found."
    exit
}

$members = Get-ADGroupMember -Identity $groupName

# Create an array to hold the results
$result = @()

foreach ($member in $members) {
    if ($member.objectClass -eq "user") {
        if ($membersList -contains $member.SamAccountName) {
            $user = Get-ADUser -Identity $member -Properties whenCreated
            # Add user details to the result array
            $result += [pscustomobject]@{
                Name          = $user.Name
                SamAccountName = $user.SamAccountName
                WhenCreated   = $user.whenCreated
            }
        }
    }
}

# Output the results in a formatted table
$result | Format-Table -AutoSize
#$result | Export-Csv -Path "C:\temp\GroupMembers.csv" -NoTypeInformation
