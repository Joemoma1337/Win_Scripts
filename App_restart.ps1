# application restart based on running services
# Configuration
$ProcessNames = @("Service1", "Service2")
$LauncherPath = "D:\Program.exe"
$LogFile      = "C:\Users\Public\Documents\Autostart_Monitor.log"
$CheckInterval = 20

# Helper function for logging
function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Dir = Split-Path -Path $LogFile -Parent
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }
    "[$Timestamp] $Message" | Add-Content -Path $LogFile
}

while ($true) {
    try {
        # 1. Identify which targeted processes are currently running
        $Running = Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue

        # 2. Check if the number of unique running processes matches our target list
        # Using .Count and Select-Object -Unique handles cases where a service might have multiple instances
        $RunningCount = ($Running | Select-Object -ExpandProperty Name -Unique).Count

        if ($RunningCount -lt $ProcessNames.Count) {
            Write-Log "Process mismatch detected (Running: $RunningCount/$($ProcessNames.Count)). Restarting..."

            # 3. Kill existing partial processes if they exist
            if ($Running) {
                $Running | Stop-Process -Force -ErrorAction SilentlyContinue
                $Running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
            }

            # 4. Start the launcher
            if (Test-Path $LauncherPath) {
                Start-Process -FilePath $LauncherPath
                Write-Log "Launcher started: $LauncherPath"
            } else {
                Write-Log "ERROR: Launcher not found at $LauncherPath"
            }
        }
    }
    catch {
        Write-Log "SCRIPT ERROR: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $CheckInterval
}
