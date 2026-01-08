# --- CONFIGURATION ---
$action   = "Enable" # Set this to "Enable" or "Disable"
$filePath = "C:\Users\Administrator\Downloads\Users\users.txt" # Defined once here
$logFile  = "C:\Users\Administrator\Downloads\Users\account_actions.log"
# ---------------------

# Verify the file actually exists before starting
if (-not (Test-Path $filePath)) {
    Write-Error "The file at $filePath was not found."
    return
}

# Load the list using the correct variable
$userList = Get-Content $filePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

foreach ($samAccount in $userList) {
    $samAccount = $samAccount.Trim() # Remove accidental spaces

    try {
        # Verify user exists
        $user = Get-ADUser -Identity $samAccount -ErrorAction Stop
        
        if ($action -eq "Disable") {
            Disable-ADAccount -Identity $samAccount
            $status = "DISABLED"
        } 
        else {
            Enable-ADAccount -Identity $samAccount
            $status = "ENABLED"
        }

        $message = "$(Get-Date -Format 'HH:mm:ss') : SUCCESS : Account '$samAccount' $status."
        Write-Host $message -ForegroundColor Green
        $message | Out-File -FilePath $logFile -Append
    }
    catch {
        $message = "$(Get-Date -Format 'HH:mm:ss') : ERROR   : User '$samAccount' - $($_.Exception.Message)"
        Write-Host $message -ForegroundColor Red
        $message | Out-File -FilePath $logFile -Append
    }
}
