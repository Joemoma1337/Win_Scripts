# --- CONFIGURATION ---
$action   = "Enable" # Set this to "Enable", "Disable", or "Unlock"
$filePath = "C:\Users\Administrator\Downloads\Users\users.txt"
$logFile  = "C:\Users\Administrator\Downloads\Users\account_actions.log"
# ---------------------

if (-not (Test-Path $filePath)) {
    Write-Error "The file at $filePath was not found."
    return
}

$userList = Get-Content $filePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

# Helper function to print colored status words to console
function Write-ColoredStatus {
    param($status)
    $color = "White"
    if ($status -eq "Enabled" -or $status -eq "Unlocked") { $color = "Green" }
    if ($status -eq "Disabled" -or $status -eq "Locked") { $color = "Red" }
    Write-Host $status -ForegroundColor $color -NoNewline
}

foreach ($samAccount in $userList) {
    $samAccount = $samAccount.Trim()

    try {
        # 1. Get Initial Status
        $user = Get-ADUser -Identity $samAccount -Properties Enabled, LockedOut -ErrorAction Stop
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

        # 4. Report Results
        $timestamp = Get-Date -Format 'HH:mm:ss'
        
        # Write to Terminal with inline colors
        Write-Host "$timestamp : SUCCESS : User '$samAccount' | Action: $action | Before: (" -NoNewline
        Write-ColoredStatus $initialEnabled
        Write-Host " | " -NoNewline
        Write-ColoredStatus $initialLocked
        Write-Host ") | After: (" -NoNewline
        Write-ColoredStatus $finalEnabled
        Write-Host " | " -NoNewline
        Write-ColoredStatus $finalLocked
        Write-Host ")"

        # Write to Log File (Plain text)
        $logMsg = "$timestamp : SUCCESS : User '$samAccount' | Action: $action | Before: ($initialEnabled | $initialLocked) | After: ($finalEnabled | $finalLocked)"
        $logMsg | Out-File -FilePath $logFile -Append
    }
    catch {
        $errorMsg = "$(Get-Date -Format 'HH:mm:ss') : ERROR   : User '$samAccount' - $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $errorMsg | Out-File -FilePath $logFile -Append
    }
}
