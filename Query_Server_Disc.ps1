# --- CONFIGURATION ---
$serverFile = "C:\Users\Administrator\Downloads\servers.txt" 
$servers = Get-Content $serverFile
$logFile = "C:\Users\Administrator\Downloads\Disc_session_report.log"
# ---------------------

foreach ($server in $servers) {
    if ([string]::IsNullOrWhiteSpace($server)) { continue }

    try {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
            
            $header = "`n--- Server: $server ---"
            $header | Tee-Object -FilePath $logFile -Append

            # 1. Run qwinsta and capture output
            $allSessions = qwinsta /server:$server 2>&1
            
            # 2. Filter for the Header line OR lines containing "Disc"
            # This ensures you keep the "SESSIONNAME USERNAME ID STATE" labels
            $discSessions = $allSessions | Where-Object { $_ -match "SESSIONNAME" -or $_ -match "Disc" -and $_ -notmatch "services" }

            # 3. Output only if sessions were found (besides the header)
            if ($discSessions.Count -gt 1) {
                $discSessions | Tee-Object -FilePath $logFile -Append
            } else {
                $noSessionMsg = "No disconnected sessions found."
                $noSessionMsg | Tee-Object -FilePath $logFile -Append
            }
        }
        else {
            $offlineMsg = "ERROR: $server is OFFLINE or unreachable."
            $offlineMsg | Tee-Object -FilePath $logFile -Append
        }
    }
    catch {
        $errorMsg = "ERROR: Could not query $server. Check permissions."
        $errorMsg | Tee-Object -FilePath $logFile -Append
    }
}
