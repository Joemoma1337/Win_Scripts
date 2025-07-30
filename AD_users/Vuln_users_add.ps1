# Requires -Modules ActiveDirectory

# Load the first names, last names, and passwords from text files
# Filter out any empty or whitespace-only lines
$firstNames = Get-Content -Path "firstname.txt" | Where-Object { $_.Trim() -ne "" }
$lastNames = Get-Content -Path "lastname.txt" | Where-Object { $_.Trim() -ne "" }
$passwords = Get-Content -Path "password.txt" | Where-Object { $_.Trim() -ne "" }

# Check if the source files have content
if ($firstNames.Count -eq 0) {
    Write-Error "firstname.txt is empty or missing content. Please ensure it contains names."
    exit 1
}
if ($lastNames.Count -eq 0) {
    Write-Error "lastname.txt is empty or missing content. Please ensure it contains names."
    exit 1
}
if ($passwords.Count -eq 0) {
    Write-Error "password.txt is empty or missing content. Please ensure it contains passwords."
    exit 1
}

# Specify the OU path where users will be created
$OUPath = "OU=vulnerable,DC=lab,DC=local"
$DomainDN = "DC=lab,DC=local" # Separate domain DN for OU creation

# Check if the OU exists, and create it if it doesn't
Write-Host "Checking for OU: $OUPath"
$ouExists = $null # Initialize to null
try {
    # Attempt to get the OU. If it doesn't exist, this will throw an error caught below.
    $ouExists = Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop
    Write-Host "OU '$OUPath' already exists."
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Host "OU '$OUPath' does not exist. Attempting to create it."
    try {
        New-ADOrganizationalUnit -Name "vulnerable" -Path $DomainDN -ErrorAction Stop
        Write-Host "OU 'vulnerable' has been created."
        # After creation, retrieve the OU object to confirm
        $ouExists = Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to create OU 'vulnerable'. Error: $($_.Exception.Message)"
        exit 1 # Exit script if OU creation fails
    }
}
catch {
    Write-Error "An unexpected error occurred while checking for OU '$OUPath'. Error: $($_.Exception.Message)"
    exit 1 # Exit script on other unexpected errors
}

# Ensure VulnerableUsers group exists
$groupName = "VulnerableUsers"
$groupDN = "CN=$groupName,$OUPath" # Construct the full DN for the group within the OU

Write-Host "Checking for Security Group: $groupName"
if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
    Write-Host "Security group '$groupName' does not exist. Creating it."
    try {
        New-ADGroup -Name $groupName -GroupScope Global -Path $OUPath -GroupCategory Security -Description "Group for intentionally vulnerable lab users" -ErrorAction Stop
        Write-Host "Security group '$groupName' created successfully."
    }
    catch {
        Write-Error "Failed to create security group '$groupName'. Error: $($_.Exception.Message)"
        exit 1 # Exit script if group creation fails
    }
} else {
    Write-Host "Security group '$groupName' already exists."
}

# Number of users to create
$numberOfUsers = 101  # Change this number to create more or fewer users

Write-Host "`nStarting user creation process for $numberOfUsers users..."

# Loop to create users
for ($i = 1; $i -le $numberOfUsers; $i++) {
    Write-Host "--- Creating User $i of $numberOfUsers ---"

    # Randomly select a first name and last name, ensuring they are not empty
    $firstName = ($firstNames | Get-Random).Trim()
    $lastName = ($lastNames | Get-Random).Trim()

    # Skip if either name is empty after trimming (unlikely with filters above, but good safeguard)
    if ([string]::IsNullOrEmpty($firstName) -or [string]::IsNullOrEmpty($lastName)) {
        Write-Warning "Skipping user creation for an empty first or last name. Iteration: $i. Please check your name files."
        continue # Move to the next iteration of the loop
    }

    # Create the full name and given name
    $fullName = "$firstName $lastName"
    $givenName = $firstName

    # Generate a base SamAccountName
    # Ensure firstName has at least 1 character for substring
    $baseSam = ($firstName.Substring(0, [Math]::Min(2, $firstName.Length)) + $lastName).ToLower()
    $samAccountName = $baseSam
    $counter = 1

    # Ensure uniqueness of SamAccountName
    while (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
        $samAccountName = "$baseSam$counter"
        $counter++
        if ($counter -gt 1000) { # Prevent infinite loop for extremely common names
            Write-Warning "Could not find a unique SamAccountName for $baseSam after 1000 attempts. Skipping user $fullName."
            continue 2 # Continue to the next iteration of the outer loop (for loop)
        }
    }

    # Create the UserPrincipalName
    $userPrincipalName = "$samAccountName@lab.local"

    # Randomly select a password, ensuring it's not empty
    $password = ($passwords | Get-Random).Trim()
    if ([string]::IsNullOrEmpty($password)) {
        Write-Warning "Skipping user '$fullName' due to an empty password selected from password.txt. Iteration: $i."
        continue # Move to the next iteration of the loop
    }
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create the new user in Active Directory
    try {
        Write-Host "Attempting to create user: $fullName (SamAccountName: $samAccountName, UPN: $userPrincipalName)"

        New-ADUser -Name $fullName `
                   -GivenName $givenName `
                   -SamAccountName $samAccountName `
                   -UserPrincipalName $userPrincipalName `
                   -Path $OUPath `
                   -AccountPassword $securePassword `
                   -Enabled $true `
                   -ChangePasswordAtLogon $false `
                   -PasswordNeverExpires $true `
                   -Description "Vulnerable test user for lab" `
                   -ErrorAction Stop # Critical: Stop if user creation itself fails

        Write-Host "Successfully created user: $fullName"

        # --- Enhanced Group Membership Logic ---

        # Immediately retrieve the user object after creation to ensure it's fully present in AD
        # This is more robust than relying solely on the output of New-ADUser for group membership
        # Add a very small sleep if you suspect replication delays in a busy AD environment, e.g., Start-Sleep -Milliseconds 50
        $userObjectForGroup = Get-ADUser -Identity $samAccountName -ErrorAction SilentlyContinue

        if ($userObjectForGroup) {
            Write-Host "Found user object for $samAccountName. Adding to group '$groupName'..."
            # Add the user to the VulnerableUsers group using DistinguishedName for robustness
            Add-ADGroupMember -Identity $groupName -Members $userObjectForGroup.DistinguishedName -ErrorAction Stop
            Write-Host "Successfully added user '$fullName' ($samAccountName) to group '$groupName'."
        } else {
            Write-Warning "User '$fullName' ($samAccountName) was reportedly created, but could not be found via Get-ADUser for group membership. Skipping group add for this user."
        }

    }
    catch {
        # This catch block will execute if New-ADUser, Get-ADUser, or Add-ADGroupMember fails
        Write-Error "Failed during user creation or group addition for '$fullName' ($samAccountName). Error: $($_.Exception.Message)"
    }
    Write-Host "" # Blank line for readability between users
}

Write-Host "Script execution completed. Check your Active Directory for created users and group memberships."
