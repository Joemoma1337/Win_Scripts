# --- CONFIGURATION ---
$action = "Enable" # Set this to "Enable" or "Disable"
$userList = Get-Content "C:\Users\Administrator\Downloads\users.txt"
$logFile = "C:\Users\Administrator\Downloads\account_actions.log"
# ---------------------

$userList = Get-Content $userFile

foreach ($samAccount in $userList) {
    if ([string]::IsNullOrWhiteSpace($samAccount)) { continue } # Skip empty lines

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
        $message | Tee-Object -FilePath $logFile -Append
    }
    catch {
        $message = "$(Get-Date -Format 'HH:mm:ss') : ERROR   : User '$samAccount' not found."
        $message | Tee-Object -FilePath $logFile -Append
    }
}
