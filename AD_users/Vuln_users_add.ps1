# Load the first names, last names, and passwords from text files
$firstNames = Get-Content -Path "firstname.txt"
$lastNames = Get-Content -Path "lastname.txt"
$passwords = Get-Content -Path "password.txt"

# Specify the OU path where users will be created
$OUPath = "OU=vulnerable,DC=lab,DC=local"

# Check if the OU exists
$ouExists = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OUPath'" -ErrorAction SilentlyContinue

# If the OU does not exist, create it
if (-not $ouExists) {
    New-ADOrganizationalUnit -Name "vulnerable" -Path "DC=lab,DC=local"
    Write-Host "OU 'vulnerable' has been created."
} else {
    Write-Host "OU 'vulnerable' already exists."
}

# Ensure VulnerableUsers group exists
$groupName = "VulnerableUsers"
if (-not (Get-ADGroup -Filter { Name -eq $groupName } -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $groupName -GroupScope Global -Path $OUPath -GroupCategory Security -Description "Group for intentionally vulnerable lab users"
    Write-Host "Security group '$groupName' created."
} else {
    Write-Host "Security group '$groupName' already exists."
}

# Number of users to create
$numberOfUsers = 100  # Change this number to create more or fewer users

# Loop to create users
for ($i = 1; $i -le $numberOfUsers; $i++) {
    # Randomly select a first name and last name
    $firstName = $firstNames | Get-Random
    $lastName = $lastNames | Get-Random

    # Create the full name and given name
    $fullName = "$firstName $lastName"
    $givenName = $firstName

    # Generate a base SamAccountName
    $baseSam = ($firstName.Substring(0, [Math]::Min(2, $firstName.Length)) + $lastName).ToLower()
    $samAccountName = $baseSam
    $counter = 1

    # Ensure uniqueness of SamAccountName
    while (Get-ADUser -Filter { SamAccountName -eq $samAccountName } -ErrorAction SilentlyContinue) {
        $samAccountName = "$baseSam$counter"
        $counter++
    }

    # Create the UserPrincipalName
    $userPrincipalName = "$samAccountName@lab.local"

    # Randomly select a password and convert it to secure string
    $password = $passwords | Get-Random
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create the new user in Active Directory
    New-ADUser -Name $fullName `
               -GivenName $givenName `
               -SamAccountName $samAccountName `
               -UserPrincipalName $userPrincipalName `
               -Path $OUPath `
               -AccountPassword $securePassword `
               -Enabled $true `
               -ChangePasswordAtLogon $false `
               -PasswordNeverExpires $true `
               -Description "Vulnerable test user for lab"

    # Add the user to the VulnerableUsers group
    Add-ADGroupMember -Identity $groupName -Members $samAccountName

    # Output the created user
    Write-Host "Created user: $fullName | SamAccountName: $samAccountName | UPN: $userPrincipalName"
}
