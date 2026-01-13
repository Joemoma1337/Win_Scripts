<#
.SYNOPSIS
    Decommissions a user by updating attributes, moving to a termination OU, and renaming the CN.
    
.NOTES
    This version uses the Pipeline and -PassThru to handle DistinguishedName changes 
    instantly without needing AD replication delays or re-queries.
#>

# --- Configuration ---
$samAccountName  = "SAM_Name"             # The original SAM name
$targetOU        = "CN=Users,DC=domain,DC=com"
$descriptionText = "ticket#"
$domainSuffix    = "@domain.com"          # Adjust as needed

# --- Execution ---
Import-Module ActiveDirectory

# 1. Fetch user once with all necessary properties
$user = Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -Properties Description, EmployeeID, Name

if ($user) {
    try {
        Write-Host "Starting decommissioning for: $($user.DistinguishedName)" -ForegroundColor Cyan

        # 2. Define attribute updates in a hash table (Splatting)
        # This performs all changes in a single AD write operation.
        $newSam = "term_$($user.SamAccountName)"
        $userUpdate = @{
            DisplayName       = "term_$($user.Name)"
            UserPrincipalName = "$newSam$domainSuffix"
            SamAccountName    = $newSam
            Description       = "$($user.Description) | $descriptionText"
            EmployeeID        = "term_$($user.EmployeeID)"
        }

        Write-Host "[1/3] Updating user attributes..." -ForegroundColor Yellow
        $user | Set-ADUser @userUpdate

        # 3. Move and Rename using the Pipeline
        # Move-ADObject -PassThru outputs the object with its NEW DistinguishedName.
        # This allows Rename-ADObject to work immediately without a re-query.
        Write-Host "[2/3] Moving user to: $targetOU" -ForegroundColor Yellow
        Write-Host "[3/3] Renaming Common Name (CN) to: $newSam" -ForegroundColor Yellow

        $user | Move-ADObject -TargetPath $targetOU -PassThru | 
                Rename-ADObject -NewName $newSam

        Write-Host "`nSuccess: User decommissioned and moved to $targetOU" -ForegroundColor Green

    } catch {
        Write-Error "An error occurred during the update: $($_.Exception.Message)"
    }
} else {
    Write-Host "Error: User with SAM Account Name '$samAccountName' not found." -ForegroundColor Red
}
