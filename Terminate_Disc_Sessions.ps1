# --- CONFIGURATION ---
$serverFile = "C:\Users\Administrator\Downloads\Server\servers.txt"
$logFile = "C:\Users\Administrator\Downloads\Server\term_disc_report.log"
# ---------------------

$servers = Get-Content $serverFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

foreach ($server in $servers) {
    $server = $server.Trim()
    Write-Host "`nProcessing $server..." -ForegroundColor Cyan

    try {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
            
            $sessions = qwinsta /server:$server 2>&1
            
            # Filter for 'Disc' and exclude 'services'
            $discSessions = $sessions | Where-Object { $_ -match "Disc" -and $_ -notmatch "services" }

            if ($null -eq $discSessions) {
                Write-Host "  No disconnected sessions found." -ForegroundColor Gray
                continue
            }

            foreach ($session in $discSessions) {
                # REGEX EXPLANATION:
                # ^\s* : Start of line and any leading space
                # (\S+)    : Group 1 - The Username (first set of non-whitespace characters)
                # \s+      : Spaces
                # (\d+)    : Group 2 - The Session ID (digits)
                # \s+Disc  : The word Disc
                if ($session.Trim() -match "^(\S+)\s+(\d+)\s+Disc") {
                    $userName  = $matches[1]
                    $sessionId = $matches[2]
                    
                    # Execute LOGOFF
                    $result = logoff $sessionId /server:$server /v 2>&1
                    
                    $msg = "$(Get-Date -Format 'HH:mm:ss') : SUCCESS : Logged off User [$userName] (ID: $sessionId) on $server"
                    Write-Host "  $msg" -ForegroundColor Green
                    $msg | Out-File -FilePath $logFile -Append
                }
            }
        } 
        else {
            $offlineMsg = "$(Get-Date -Format 'HH:mm:ss') : ERROR : $server is OFFLINE."
            Write-Host "  $offlineMsg" -ForegroundColor Red
            $offlineMsg | Out-File -FilePath $logFile -Append
        }
    }
    catch {
        $errorMsg = "$(Get-Date -Format 'HH:mm:ss') : ERROR : Failed to process $server. $($_.Exception.Message)"
        Write-Host "  $errorMsg" -ForegroundColor Yellow
        $errorMsg | Out-File -FilePath $logFile -Append
    }
}
