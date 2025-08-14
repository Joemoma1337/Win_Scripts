#powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Path\To\Your\Script.ps1"
# --- Configuration ---
# Define process names, launcher path, and log file path at the top for easy management.
$ProcessNames = "Service1", "Service2"
$LauncherPath = "D:\Program.exe"
$LogFile = "C:\Users\Public\Documents\Autostart_Error.log" # IMPORTANT: Change this path

# --- Main Loop ---
while ($true) {
    try {
        # Get all relevant processes in a single, more efficient call.
        $runningProcesses = Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue

        # Check if BOTH processes are running.
        $isService1Running = $false
        $isService2Running = $false

        if ($runningProcesses) {
            # Use the -contains operator for an efficient check against the collection of process names.
            $isService1Running = $runningProcesses.Name -contains 'Service1'
            $isService2Running = $runningProcesses.Name -contains 'Service2'
        }

        # Simplified Logic: If the desired state (both running) is not met, take action.
        if (-not ($isService1Running -and $isService2Running)) {
            
            # If any of the target processes are running, stop them.
            # This is more reliable than stopping them by separate IDs.
            if ($runningProcesses) {
                Stop-Process -InputObject $runningProcesses -Force -ErrorAction SilentlyContinue
                # Wait for processes to terminate cleanly before restarting.
                Start-Sleep -Seconds 5
            }
            
            # Start the launcher.
            Start-Process -FilePath $LauncherPath
        }
    }
    catch {
        # Log any unexpected script-breaking errors to a file.
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $errorMessage = "[$timestamp] SCRIPT ERROR: $($_.Exception.Message)"
        
        # Ensure the directory for the log file exists.
        $LogDirectory = Split-Path -Path $LogFile -Parent
        if (-not (Test-Path -Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory | Out-Null
        }
        
        # Append the error to the log file.
        Add-Content -Path $LogFile -Value $errorMessage
    }
    
    # The main polling interval for the check.
    Start-Sleep -Seconds 20
}
