# Define the target folder (CN=Users since it's a built-in container)
$targetOU = "CN=Users,DC=domain,DC=com"  # Replace with your domain details
$samAccountName = "SAM_Name"             # Replace with the user's SAM account name
$descriptionText = "ticket#"              # Text to append to the description

# Import Active Directory module
Import-Module ActiveDirectory

# Get the user object
$user = Get-ADUser -Filter {SamAccountName -eq $samAccountName} -Properties SamAccountName, UserPrincipalName, DistinguishedName, Description, EmployeeID, Name

if ($user) {
    # Build the new attributes
    $newDisplayName = "term_$($user.Name)"
    $newUPN = "term_$($user.SamAccountName)@domain.com"  # Adjust domain suffix as needed
    $newSAM = "term_$($user.SamAccountName)"
    $newDescription = "$($user.Description) | $descriptionText"
    $newEmployeeID = "term_$($user.EmployeeID)"  # Prepend "term_" to EmployeeID

    # Move the user first
    Write-Host "Moving user '$($user.SamAccountName)' to '$targetOU'..." -ForegroundColor Yellow
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOU

    # Re-fetch the updated user DN after the move
    Start-Sleep -Seconds 2  # Small delay to allow AD replication
    $user = Get-ADUser -Filter {SamAccountName -eq $samAccountName} -Properties DistinguishedName

    # Rename CN (Common Name)
    Write-Host "Renaming CN to '$newSAM'..." -ForegroundColor Yellow
    Rename-ADObject -Identity $user.DistinguishedName -NewName $newSAM

    # Update attributes
    Write-Host "Updating display name to '$newDisplayName'..." -ForegroundColor Yellow
    Set-ADUser -Identity $newSAM -DisplayName $newDisplayName

    Write-Host "Updating UPN to '$newUPN'..." -ForegroundColor Yellow
    Set-ADUser -Identity $newSAM -UserPrincipalName $newUPN

    Write-Host "Updating description to include '$descriptionText'..." -ForegroundColor Yellow
    Set-ADUser -Identity $newSAM -Description $newDescription

    Write-Host "Updating EmployeeID to '$newEmployeeID'..." -ForegroundColor Yellow
    Set-ADUser -Identity $newSAM -EmployeeID $newEmployeeID

    # Update sAMAccountName properly
    Write-Host "Updating SAM account name to '$newSAM'..." -ForegroundColor Yellow
    Set-ADUser -Identity $newSAM -SamAccountName $newSAM

    Write-Host "User '$newSAM' successfully updated and moved." -ForegroundColor Green
} else {
    Write-Host "User with SAM Account Name '$samAccountName' not found in AD." -ForegroundColor Red
}
