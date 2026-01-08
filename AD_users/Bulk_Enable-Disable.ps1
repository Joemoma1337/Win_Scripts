# --- CONFIGURATION ---
$action   = "Enable" # Set this to "Enable" or "Disable"
$filePath = "C:\Users\Administrator\Downloads\Users\users.txt"
$logFile  = "C:\Users\Administrator\Downloads\Users\account_actions.log"
# ---------------------

if (-not (Test-Path $filePath)) {
    Write-Error "The file at $filePath was not found."
    return
}

$userList = Get-Content $filePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

foreach ($samAccount in $userList) {
    $samAccount = $samAccount.Trim()

    try {
        # 1. Get Initial Status
        $user = Get-ADUser -Identity $samAccount -Properties Enabled -ErrorAction Stop
        $initialStatus = if ($user.Enabled) { "Enabled" } else { "Disabled" }
        
        # 2. Perform Action
        if ($action -eq "Disable") {
            Disable-ADAccount -Identity $samAccount -Confirm:$false
            $targetStatus = "Disabled"
        } 
        else {
            Enable-ADAccount -Identity $samAccount -Confirm:$false
            $targetStatus = "Enabled"
        }

        # 3. Verify Final Status
        $updatedUser = Get-ADUser -Identity $samAccount -Properties Enabled
        $finalStatus = if ($updatedUser.Enabled) { "Enabled" } else { "Disabled" }

        # 4. Report Results
        $msg = "$(Get-Date -Format 'HH:mm:ss') : SUCCESS : User '$samAccount' | Before: $initialStatus | After: $finalStatus"
        
        # Color coding for terminal visibility
        if ($initialStatus -eq $finalStatus) {
            Write-Host $msg -ForegroundColor Yellow # No change occurred
        } else {
            Write-Host $msg -ForegroundColor Green  # Success
        }

        $msg | Out-File -FilePath $logFile -Append
    }
    catch {
        $errorMsg = "$(Get-Date -Format 'HH:mm:ss') : ERROR   : User '$samAccount' - $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $errorMsg | Out-File -FilePath $logFile -Append
    }
}
