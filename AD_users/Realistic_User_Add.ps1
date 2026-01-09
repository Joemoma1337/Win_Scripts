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

    [Parameter(Mandatory = $false, HelpMessage = "The path and filename for the log file.")]
    [string]$LogFilePath = ".\user_creation_log.txt"
)

# --- HARD-CODED VARIABLES ---
# The total number of users to create and the time window are now set here instead of as parameters.
[int]$NumberOfUsers = 1500
[int]$TotalMinutes = 5760

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

Write-Host "Starting user creation process..."
Write-Host ""

# --- NEW TIMING LOGIC ---
# This new logic generates a random schedule for all user creations within the specified total minutes.
Write-Host "Generating a random creation schedule for $NumberOfUsers users within the next $TotalMinutes minutes."

# Get the script's start time and calculate the total duration in seconds
$startTime = Get-Date
$totalSeconds = $TotalMinutes * 60

# Generate a list of random second offsets from the start time.
# Each offset represents a point in time when a user will be created.
$creationScheduleSeconds = 1..$NumberOfUsers | ForEach-Object { Get-Random -Minimum 1 -Maximum $totalSeconds }

# Sort the schedule to process users in chronological order
$sortedSchedule = $creationScheduleSeconds | Sort-Object

Write-Host "Random schedule generated. Starting user creation process..."
Write-Host ""


# --- MAIN USER CREATION LOOP ---
# This loop now iterates through the pre-generated random schedule.
for ($i = 0; $i -lt $NumberOfUsers; $i++) {
    $userIndex = $i + 1
    $scheduledSecond = $sortedSchedule[$i]
    
    # Calculate the exact time this user should be created based on the schedule
    $targetCreationTime = $startTime.AddSeconds($scheduledSecond)
    
    # Calculate how long we need to wait to reach that specific time
    $currentTime = Get-Date
    $timeToWait = New-TimeSpan -Start $currentTime -End $targetCreationTime
    
    Write-Host "--- Preparing to Create User $userIndex of $NumberOfUsers ---"
    
    # Only sleep if the target time is in the future.
    # This handles cases where previous user creations took longer than expected.
    if ($timeToWait.TotalSeconds -gt 0) {
        $waitMinutes = [math]::Floor($timeToWait.TotalMinutes)
        $waitSeconds = $timeToWait.Seconds
        Write-Host "Next user is scheduled for creation at: $targetCreationTime. Waiting for $waitMinutes minutes and $waitSeconds seconds."
        Start-Sleep -Seconds $timeToWait.TotalSeconds
    } else {
        Write-Host "Scheduled time for this user has already passed. Proceeding with creation immediately."
    }

    # Use a do/while loop to retry the entire creation process if any unique attribute already exists or if
    # the generated SamAccountName is too long.
    do {
        $userCreatedSuccessfully = $false
        # Randomly select a first name and last name, ensuring they are not empty
        $firstName = ($firstNames | Get-Random).Trim()
        $lastName = ($lastNames | Get-Random).Trim()
        
        # Skip if either name is empty after trimming
        if ([string]::IsNullOrEmpty($firstName) -or [string]::IsNullOrEmpty($lastName)) {
            Write-Warning "Skipping user creation for an empty first or last name. Please check your name files."
            continue
        }

        # Generate unique full name (CN), SamAccountName, and EmployeeID
        $fullName = "$firstName $lastName"
        $givenName = $firstName
        $samAccountName = "$firstName.$lastName".ToLower()
        $userPrincipalName = "$samAccountName@$((Get-ADDomain).DNSRoot)" # More reliable way to get domain DNS name
        $employeeID = "ID" + (Get-Random -Minimum 1000000 -Maximum 9999999)

        # Check for conflicts and length violations in a single, more efficient query
        $samAccountNameTooLong = $samAccountName.Length -gt 20
        $userExists = $false
        if (-not $samAccountNameTooLong) {
            $filter = "(Name -eq '$fullName') -or (SamAccountName -eq '$samAccountName') -or (EmployeeID -eq '$employeeID')"
            if (Get-ADUser -Filter $filter -Properties EmployeeID -ErrorAction SilentlyContinue) {
                $userExists = $true
            }
        }

        if ($userExists -or $samAccountNameTooLong) {
            # This is a short, randomized retry delay to handle naming conflicts.
            Write-Host "One or more user attributes already exist or are invalid. Regenerating attributes and retrying..."
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3) # Short delay before retry
        }
    } while ($userExists -or $samAccountNameTooLong)

    # Randomly select a password, ensuring it's not empty
    $password = ($passwords | Get-Random).Trim()
    if ([string]::IsNullOrEmpty($password)) {
        Write-Warning "Skipping user '$fullName' due to an empty password selected from password.txt."
        continue
    }
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create the new user in Active Directory
    try {
        Write-Host "Attempting to create user: $fullName (SamAccountName: $samAccountName, UPN: $userPrincipalName, Employee ID: $employeeID)"

        # Use -PassThru to get the new user object back without a second query
        $newUserObject = New-ADUser -Name $fullName `
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
            -PassThru `
            -ErrorAction Stop

        Write-Host "Successfully created user: $fullName"

        # Randomly assign the new user to one of the security groups
        $randomGroup = $GroupNames | Get-Random
        Write-Host "Adding user '$fullName' to group '$randomGroup'..."
        Add-ADGroupMember -Identity $randomGroup -Members $newUserObject -ErrorAction Stop
        Write-Host "Successfully added user to group '$randomGroup'."
        
        # --- Logging Logic ---
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "$timestamp - User created: $samAccountName, Group: $randomGroup"
        Add-Content -Path $LogFilePath -Value $logEntry
        Write-Host "Logged user creation for '$samAccountName' to '$LogFilePath'."

    }
    catch {
        Write-Error "Failed during user creation or group addition for '$fullName' ($samAccountName). Error: $($_.Exception.Message)"
    }
    Write-Host "" # Blank line for readability
}

Write-Host "Script execution completed. All scheduled user creations have been attempted."
