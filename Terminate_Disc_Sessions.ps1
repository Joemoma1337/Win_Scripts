# --- CONFIGURATION ---
$serverFile = "C:\Users\Administrator\Downloads\servers.txt"
$logFile = "C:\Users\Administrator\Downloads\cleanup_sessions.log"
# ---------------------

$servers = Get-Content $serverFile

foreach ($server in $servers) {
    if ([string]::IsNullOrWhiteSpace($server)) { continue }

    try {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
            Write-Host "Processing $server..." -ForegroundColor Cyan
            
            # 1. Query sessions and filter for 'Disc' (Disconnected)
            # Skip the first line (header) and look for the "Disc" state
            $discSessions = qwinsta /server:$server | Where-Object { $_ -match "Disc" }

            foreach ($session in $discSessions) {
                # 2. Extract the Session ID (the numeric value in the row)
                # Regex looks for the digits following the username
                if ($session -match "(\d+)\s+Disc") {
                    $sessionId = $matches[1]
                    
                    # 3. Reset (Disconnect/Logoff) the session
                    rwinsta $sessionId /server:$server
                    
                    $msg = "$(Get-Date -Format 'HH:mm:ss') : SUCCESS : Reset Session ID $sessionId on $server"
                    $msg | Tee-Object -FilePath $logFile -Append
                }
            }
        } else {
            "$(Get-Date -Format 'HH:mm:ss') : ERROR : $server is offline." | Tee-Object -FilePath $logFile -Append
        }
    }
    catch {
        "$(Get-Date -Format 'HH:mm:ss') : ERROR : Failed to process $server. $_" | Tee-Object -FilePath $logFile -Append
    }
}
