$msiUrl = "https://dl.tailscale.com/stable/tailscale-setup-1.86.2-amd64.msi" 
$msiPath = "$env:TEMP\tailscale-installer.msi"
$tailscaleExePath = Join-Path -Path $env:ProgramW6432 -ChildPath "Tailscale\tailscale.exe"
taskkill /IM tailscale-ipn.exe /F
# --- Step 4: Verify Installation and Proceed to Activation ---
if (Test-Path -Path $tailscaleExePath) {
    Write-Host "Tailscale has been successfully installed."

    # Choose ONE of the following activation methods below.
    # --- METHOD A: Interactive Activation (Requires a browser login) ---
    # Write-Host "Running `tailscale up`. Please complete the authentication in your browser."
    # & "$tailscaleExePath" up

    # --- METHOD B: Unattended Activation with an Auth Key (For automation) ---
    $AuthKey = "tskey-auth-UPDATE-KEY"
    Write-Host "Activating Tailscale with an authentication key..."
    & "$tailscaleExePath" up --authkey "$AuthKey"
    
    Write-Host "Tailscale activation command executed."
} else {
    Write-Error "Tailscale executable not found at '$tailscaleExePath'. The installation may have failed."
}
# --- Step 1: Set Variables for the Download ---
# The URL for the raw file on GitHub.
$psexecUrl = "https://github.com/Joemoma1337/Win_Scripts/raw/refs/heads/main/PsExec.exe"

# The path where you want to save the downloaded file.
# We'll save it to the current user's Downloads folder for convenience.
$psexecPath = "$env:USERPROFILE\Downloads\PsExec.exe"

# --- Step 2: Download the file using Invoke-WebRequest ---
Write-Host "Starting download of PsExec.exe from GitHub..."

try {
    # The -OutFile parameter specifies where to save the downloaded content.
    Invoke-WebRequest -Uri $psexecUrl -OutFile $psexecPath
    Write-Host "Download successful! File saved to: $psexecPath"
    
    # --- Step 3: (Optional) Verify the file exists ---
    if (Test-Path -Path $psexecPath) {
        Write-Host "File verified. You can now use PsExec.exe."
    } else {
        Write-Error "Download completed, but the file was not found at the specified path."
    }
}
catch {
    # If an error occurs during the download, this block will be executed.
    Write-Error "Failed to download PsExec.exe. Error details:"
    Write-Error $_.Exception.Message
}
