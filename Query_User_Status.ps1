# Path to input and output files
$userList  = "C:\Users\user\Downloads\Users\users.txt"
$logFile   = "C:\Users\user\Downloads\Users\UserBulkAction_Log.txt"

"=== AD User Status Check $(Get-Date) ===" | Out-File -FilePath $logFile

$users = Get-Content -Path $userList

foreach ($u in $users) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $user = Get-ADUser -Filter "SamAccountName -eq '$u'" -Properties Enabled, LockedOut -ErrorAction SilentlyContinue

    if ($user) {
        # Determine statuses
        $enabledStatus = if ($user.Enabled) { "ENABLED" } else { "DISABLED" }
        $lockStatus    = if ($user.LockedOut) { "LOCKED" } else { "UNLOCKED" }
        
        # Build the base message (printed in yellow)
        $prefix = "$ts  $u account found ("

        # Write prefix in yellow
        Write-Host $prefix -NoNewline -ForegroundColor Yellow

        # Enabled/Disabled in color
        if ($enabledStatus -eq "DISABLED") {
            Write-Host $enabledStatus -NoNewline -ForegroundColor Red
        } else {
            Write-Host $enabledStatus -NoNewline -ForegroundColor Green
        }

        # Separator
        Write-Host "|" -NoNewline -ForegroundColor Yellow

        # Locked/Unlocked in color
        if ($lockStatus -eq "LOCKED") {
            Write-Host $lockStatus -NoNewline -ForegroundColor Red
        } else {
            Write-Host $lockStatus -NoNewline -ForegroundColor Green
        }

        # Closing parenthesis
        Write-Host ")" -ForegroundColor Yellow

        # Log file (plain text)
        "$ts  $u account found ($enabledStatus|$lockStatus)" |
            Out-File -FilePath $logFile -Append
    }

    else {
        $msg = "$ts  $u not found"
        Write-Host $msg -ForegroundColor Red
        $msg | Out-File -FilePath $logFile -Append
    }
}
