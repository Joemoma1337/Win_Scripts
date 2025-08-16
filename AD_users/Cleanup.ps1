# Requires -Modules ActiveDirectory

# Define script parameters. These should match the settings used in your creation script.
[CmdletBinding()]
param (
    # The domain DN is hard-coded to match the creation script.
    [string]$DomainDN = "DC=lab,DC=local",

    # The name of the OU where the users and groups are located.
    [string]$OUName = "vulnerable",

    # The list of group names to remove. This must match the creation script.
    [string[]]$GroupNames = @("Security_Team", "IT_Team", "HR_Team", "Training_Team", "Legal_Team", "Audit_Team", "Sales_Team", "Marketing_Team", "Logistics_Team", "Procurement_Team", "Service_Desk_Team", "Dev_Team")
)

# --- Clean up from User Creation Script ---
# This script is designed to safely remove all users, the groups, and the OU
# created by the User_Creation script.

# Remove any single or double quotes from the DomainDN for safety, just like in the creation script.
$CleanedDomainDN = $DomainDN.Trim("'").Trim('"')
$OUPath = "OU=$OUName,$CleanedDomainDN"

Write-Host "Starting Active Directory cleanup process..."
Write-Host "Targeting OU: $OUPath"
Write-Host ""

# --- Step 1: Remove all users from the specified OU ---
Write-Host "Searching for users in OU '$OUPath'..."
try {
    # Find all users in the specified OU.
    $usersToDelete = Get-ADUser -Filter * -SearchBase $OUPath -ErrorAction Stop

    if ($usersToDelete.Count -gt 0) {
        Write-Host "Found $($usersToDelete.Count) users to remove. Deleting now..."
        foreach ($user in $usersToDelete) {
            Write-Host "Attempting to remove user: $($user.SamAccountName)"
            # Use -Confirm:$false to avoid a prompt for each user.
            Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false -ErrorAction Stop
            Write-Host "Successfully removed user: $($user.SamAccountName)"
        }
    } else {
        Write-Host "No users found in OU '$OUPath'. Skipping user removal."
    }
}
catch {
    Write-Error "Failed to remove users. Error: $($_.Exception.Message)"
    Write-Error "A common reason for this error is a permissions issue. Ensure the account running this script has full control over the OU."
    # We will not exit here, in case the user removal failed but other objects can be deleted.
}
Write-Host ""

# --- Step 2: Remove the security groups ---
Write-Host "Searching for security groups: $GroupNames"
foreach ($groupName in $GroupNames) {
    try {
        # Check if the group exists before trying to remove it.
        $groupToRemove = Get-ADGroup -Identity $groupName -ErrorAction SilentlyContinue

        if ($groupToRemove) {
            Write-Host "Found group '$groupName'. Attempting to remove it..."
            # Use -Confirm:$false to avoid a prompt.
            Remove-ADGroup -Identity $groupToRemove.DistinguishedName -Confirm:$false -ErrorAction Stop
            Write-Host "Successfully removed group '$groupName'."
        } else {
            Write-Host "Security group '$groupName' not found. Skipping group removal."
        }
    }
    catch {
        Write-Error "Failed to remove group '$groupName'. Error: $($_.Exception.Message)"
        Write-Error "The account running this script must have permissions to remove groups from the specified OU."
        # We will not exit here, in case the group removal failed.
    }
}
Write-Host ""

# --- Step 3: Remove the Organizational Unit (OU) ---
Write-Host "Searching for Organizational Unit '$OUName'..."
try {
    # Check if the OU exists before trying to remove it.
    $ouToRemove = Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction SilentlyContinue

    if ($ouToRemove) {
        Write-Host "Found OU '$OUName'. Attempting to remove it."
        # The -Recursive parameter is required to delete the OU if it contains objects.
        Remove-ADOrganizationalUnit -Identity $ouToRemove.DistinguishedName -Confirm:$false -Recursive -ErrorAction Stop
        Write-Host "Successfully removed OU '$OUName'."
    } else {
        Write-Host "OU '$OUName' not found. Skipping OU removal."
    }
}
catch {
    Write-Error "Failed to remove OU '$OUName'. Error: $($_.Exception.Message)"
    Write-Error "The OU may have been deleted, or the account running the script lacks permission."
}
Write-Host ""

Write-Host "Cleanup script execution completed. Your lab environment is now cleaned up."
