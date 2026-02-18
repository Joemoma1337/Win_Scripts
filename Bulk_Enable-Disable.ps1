# --- CONFIGURATION ---
$action   = "Enable" # Set this to "Enable", "Disable", or "Unlock"
$filePath = "C:\Users\Administrator\Downloads\Users\users.txt"
$csvLog   = "C:\Users\Administrator\Downloads\Users\account_actions_audit.csv"
# ---------------------

if (-not (Test-Path $filePath)) {
    Write-Error "The file at $filePath was not found."
    return
}

if (!(Get-Module -ListAvailable ActiveDirectory)) { 
    Write-Error "The ActiveDirectory module is required."
    return 
}

$userList = Get-Content $filePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$report = @()

function Write-ColoredStatus {
    param($status)
    $color = "White"
    if ($status -eq "Enabled" -or $status -eq "Unlocked") { $color = "Green" }
    if ($status -eq "Disabled" -or $status -eq "Locked") { $color = "Red" }
    Write-Host $status -ForegroundColor $color -NoNewline
}

foreach ($samAccount in $userList) {
    $samAccount = $samAccount.Trim()
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Initialize variables
    $displayName = "Not Found"
    $initialEnabled = $initialLocked = $finalEnabled = $finalLocked = "Unknown"
    $statusResult = "Success"

    try {
        # 1. Get Initial Status (Added DisplayName to properties)
        $user = Get-ADUser -Identity $samAccount -Properties Enabled, LockedOut, DisplayName -ErrorAction Stop
        $displayName    = $user.DisplayName
        $initialEnabled = if ($user.Enabled) { "Enabled" } else { "Disabled" }
        $initialLocked  = if ($user.LockedOut) { "Locked" } else { "Unlocked" }
        
        # 2. Perform Action Logic
        switch ($action) {
            "Enable" { 
                Enable-ADAccount -Identity $samAccount -Confirm:$false
                Unlock-ADAccount -Identity $samAccount -Confirm:$false 
            }
            "Unlock" { 
                Unlock-ADAccount -Identity $samAccount -Confirm:$false 
            }
            "Disable" { 
                Disable-ADAccount -Identity $samAccount -Confirm:$false 
            }
        }

        # 3. Verify Final Status
        $updatedUser = Get-ADUser -Identity $samAccount -Properties Enabled, LockedOut
        $finalEnabled = if ($updatedUser.Enabled) { "Enabled" } else { "Disabled" }
        $finalLocked  = if ($updatedUser.LockedOut) { "Locked" } else { "Unlocked" }

        # 4. Console Feedback
        Write-Host "$timestamp : SUCCESS : '$displayName' ($samAccount) | Before: (" -NoNewline
        Write-ColoredStatus $initialEnabled; Write-Host " | " -NoNewline; Write-ColoredStatus $initialLocked
        Write-Host ") | After: (" -NoNewline
        Write-ColoredStatus $finalEnabled; Write-Host " | " -NoNewline; Write-ColoredStatus $finalLocked
        Write-Host ")"
    }
    catch {
        $statusResult = "Error: $($_.Exception.Message)"
        Write-Host "$timestamp : ERROR   : '$samAccount' - $($_.Exception.Message)" -ForegroundColor Red
    }

    # 5. Build the Object for CSV
    $report += [PSCustomObject]@{
        Time            = $timestamp
        DisplayName     = $displayName
        SAMAccount      = $samAccount
        ActionTargeted  = $action
        Status          = $statusResult
        Before_Enabled  = $initialEnabled
        Before_Locked   = $initialLocked
        After_Enabled   = $finalEnabled
        After_Locked    = $finalLocked
    }
}

# 6. Export to CSV
$report | Export-Csv -Path $csvLog -NoTypeInformation -Append -Encoding UTF8
Write-Host "`nAudit CSV updated at: $csvLog" -ForegroundColor Cyan
