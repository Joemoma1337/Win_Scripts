# --- CONFIGURATION ---
$serverFile = "C:\Users\Administrator\Downloads\servers.txt" 
$servers = Get-Content $serverFile
$logFile = "C:\Users\Administrator\Downloads\session_report.log"
# ---------------------

foreach ($server in $servers) {
    if ([string]::IsNullOrWhiteSpace($server)) { continue }

    try {
        # Check if the server is online before querying
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
            
            $header = "`n--- Server: $server ---"
            $header | Tee-Object -FilePath $logFile -Append

            # qwinsta provides: Username, Session Name, ID, State (Active/Disc)
            # We use 2>&1 to catch errors like "No sessions found" or "Access Denied"
            $sessions = qwinsta /server:$server 2>&1
            
            $sessions | Tee-Object -FilePath $logFile -Append
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
