# --- CONFIGURATION ---
$serverFile = "C:\Users\Administrator\Downloads\servers.txt"
$logFile = "C:\Users\Administrator\Downloads\cleanup_sessions.log"
# ---------------------

$servers = Get-Content $serverFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

foreach ($server in $servers) {
    $server = $server.Trim()
    Write-Host "`nProcessing $server..." -ForegroundColor Cyan

    try {
        # 1. Quick check for connectivity (Ping)
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
            
            # 2. Query sessions and look for 'Disc' (Disconnected)
            # 2>&1 ensures we capture error messages in our variable
            $sessions = qwinsta /server:$server 2>&1
            
            # Filter for rows containing "Disc"
            $discSessions = $sessions | Where-Object { $_ -match "Disc" -and $_ -notmatch "services" }

            if ($null -eq $discSessions) {
                Write-Host "  No disconnected sessions found." -ForegroundColor Gray
                continue
            }

            foreach ($session in $discSessions) {
                # 3. Extract Session ID using Regex
                # This looks for the numeric ID that appears before "Disc"
                if ($session -match "\s+(\d+)\s+Disc") {
                    $sessionId = $matches[1].Trim()
                    
                    # 4. Execute LOGOFF
                    # /v provides verbose output for our logs
                    $result = logoff $sessionId /server:$server /v 2>&1
                    
                    $msg = "$(Get-Date -Format 'HH:mm:ss') : SUCCESS : Logged off Session $sessionId on $server"
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
