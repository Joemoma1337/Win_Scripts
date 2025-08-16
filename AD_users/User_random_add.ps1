# Requires -Modules ActiveDirectory

# Define script parameters for flexibility
[CmdletBinding()]
param (
    # The domain DN is now hard-coded and will not prompt for input.
    [string]$DomainDN = "DC=lab,DC=local",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the OU to create users in.")]
    [string]$OUName = "vulnerable",

    [Parameter(Mandatory = $false, HelpMessage = "The list of group names to create and assign users to.")]
    [string[]]$GroupNames = @("Security_Team", "IT_Team", "HR_Team", "Training_Team", "Legal_Team", "Audit_Team", "Sales_Team", "Marketing_Team", "Logistics_Team", "Procurement_Team", "Service_Desk_Team", "Dev_Team"),

    [Parameter(Mandatory = $false, HelpMessage = "The number of users to create.")]
    [int]$NumberOfUsers = 1000,

    [Parameter(Mandatory = $false, HelpMessage = "The total time in minutes to spread the user creation over.")]
    [int]$TotalMinutes = 1000, # Default to 60 minutes (1 hour)

    [Parameter(Mandatory = $false, HelpMessage = "The path and filename for the log file.")]
    [string]$LogFilePath = ".\user_creation_log.txt"
)

# --- FIX for quote issue in DomainDN ---
# Remove any single or double quotes that may have been provided in the parameter input
$CleanedDomainDN = $DomainDN.Trim("'").Trim('"')
# Build the full OU path from the cleaned parameters
$OUPath = "OU=$OUName,$CleanedDomainDN"

# Load the first names, last names, and passwords from text files
# Filter out any empty or whitespace-only lines
Write-Host "Loading data from text files..."
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
Write-Host "Data loaded successfully.`n"

# Check if the OU exists, and create it if it doesn't.
Write-Host "Checking for OU: $OUPath"
if (-not (Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction SilentlyContinue)) {
    Write-Host "OU '$OUPath' does not exist. Attempting to create it."
    try {
        # Use Split-Path to get the parent and leaf names dynamically
        New-ADOrganizationalUnit -Name (Split-Path -Path $OUPath -Leaf) -Path (Split-Path -Path $OUPath -Parent) -ErrorAction Stop
        Write-Host "OU '$OUName' has been created."
    }
    catch {
        Write-Error "Failed to create OU '$OUName'. Error: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Host "OU '$OUPath' already exists."
}
Write-Host ""

# Ensure the security groups exist
Write-Host "Checking for Security Groups: $GroupNames"
foreach ($groupName in $GroupNames) {
    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
        Write-Host "Security group '$groupName' does not exist. Creating it."
        try {
            New-ADGroup -Name $groupName -GroupScope Global -Path $OUPath -GroupCategory Security -Description "Group for intentionally vulnerable lab users" -ErrorAction Stop
            Write-Host "Security group '$groupName' created successfully."
        }
        catch {
            Write-Error "Failed to create security group '$groupName'. Error: $($_.Exception.Message)"
            Write-Error "A common reason for this error is a permissions issue. The account running this script must have permissions to create security groups in the specified OU ($OUPath)."
            exit 1
        }
    } else {
        Write-Host "Security group '$groupName' already exists."
    }
}
Write-Host ""

# Calculate the average delay between users
$totalSeconds = $TotalMinutes * 60
$averageDelay = $totalSeconds / $NumberOfUsers

Write-Host "Starting user creation process for $NumberOfUsers users over $TotalMinutes minutes..."
Write-Host "Average delay between users will be approximately $($averageDelay) seconds."
Write-Host ""

# Loop to create users
for ($i = 1; $i -le $NumberOfUsers; $i++) {
    # --- Timing Logic ---
    # To create random delays, we'll get a random number of seconds centered around the average delay.
    # We'll use a range of 50% to 150% of the average delay to keep it from being too uniform or too sparse.
    $minDelay = [int]($averageDelay * 0.5)
    $maxDelay = [int]($averageDelay * 1.5)
    
    # Ensure minDelay is at least 1 second to avoid zero-second sleep and rapid-fire creation
    if ($minDelay -lt 1) { $minDelay = 1 }
    
    $randomDelay = Get-Random -Minimum $minDelay -Maximum $maxDelay
    
    Write-Host "--- Creating User $i of $NumberOfUsers ---"
    Write-Host "Sleeping for $randomDelay seconds before creating this user."
    Start-Sleep -Seconds $randomDelay
    
    # Randomly select a first name and last name, ensuring they are not empty
    $firstName = ($firstNames | Get-Random).Trim()
    $lastName = ($lastNames | Get-Random).Trim()
    
    # Skip if either name is empty after trimming
    if ([string]::IsNullOrEmpty($firstName) -or [string]::IsNullOrEmpty($lastName)) {
        Write-Warning "Skipping user creation for an empty first or last name. Iteration: $i. Please check your name files."
        continue
    }

    # Create the full name and given name
    $fullName = "$firstName $lastName"
    $givenName = $firstName

    # Generate a base SamAccountName using the new firstname.lastname format
    $baseSam = "$firstName.$lastName".ToLower()
    $samAccountName = $baseSam
    $counter = 1

    # Ensure uniqueness of SamAccountName
    while (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
        $samAccountName = "$baseSam$counter"
        $counter++
        if ($counter -gt 1000) {
            Write-Warning "Could not find a unique SamAccountName for $baseSam after 1000 attempts. Skipping user $fullName."
            continue 2
        }
    }

    # Create the UserPrincipalName
    $userPrincipalName = "$samAccountName@$((Split-Path -Path $CleanedDomainDN -Leaf).Replace('DC=',''))"
    
    # Generate a random 7-digit Employee ID
    $employeeID = "ID" + (Get-Random -Minimum 1000000 -Maximum 9999999)

    # Randomly select a password, ensuring it's not empty
    $password = ($passwords | Get-Random).Trim()
    if ([string]::IsNullOrEmpty($password)) {
        Write-Warning "Skipping user '$fullName' due to an empty password selected from password.txt. Iteration: $i."
        continue
    }
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create the new user in Active Directory
    try {
        Write-Host "Attempting to create user: $fullName (SamAccountName: $samAccountName, UPN: $userPrincipalName, Employee ID: $employeeID)"

        $newUser = New-ADUser -Name $fullName `
                   -GivenName $givenName `
                   -Surname $lastName `
                   -SamAccountName $samAccountName `
                   -UserPrincipalName $userPrincipalName `
                   -Path $OUPath `
                   -AccountPassword $securePassword `
                   -Enabled $true `
                   -ChangePasswordAtLogon $false `
                   -PasswordNeverExpires $true `
                   -Description "Vulnerable test user for lab" `
                   -EmployeeID $employeeID `
                   -ErrorAction Stop

        Write-Host "Successfully created user: $fullName"

        $userObjectForGroup = Get-ADUser -Identity $samAccountName -ErrorAction SilentlyContinue
        if ($userObjectForGroup) {
            # --- New Logic: Randomly assign to a group ---
            $randomGroup = $GroupNames | Get-Random
            Write-Host "Found user object for $samAccountName. Adding to group '$randomGroup'..."
            Add-ADGroupMember -Identity $randomGroup -Members $userObjectForGroup.DistinguishedName -ErrorAction Stop
            Write-Host "Successfully added user '$fullName' ($samAccountName) to group '$randomGroup'."
        } else {
            Write-Warning "User '$fullName' ($samAccountName) was created but could not be found for group membership. Skipping group add."
        }
        
        # --- Logging Logic ---
        # Get the current timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # Create the log entry string
        $logEntry = "$timestamp - User created: $samAccountName"
        # Append the log entry to the specified log file
        Add-Content -Path $LogFilePath -Value $logEntry
        Write-Host "Logged user creation for '$samAccountName' to '$LogFilePath'."

    }
    catch {
        Write-Error "Failed during user creation or group addition for '$fullName' ($samAccountName). Error: $($_.Exception.Message)"
    }
    Write-Host "" # Blank line for readability
}

Write-Host "Script execution completed. All $NumberOfUsers users have been created and logged."
