#OpenSSH
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) { 
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..." 
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 
} else { 
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists." 
}
Get-Service -Name "sshd"

#Tailscale
# --- Step 1: Set Variables and Define Paths ---
# Use the direct URL to the latest stable MSI installer.
$msiUrl = "https://dl.tailscale.com/stable/tailscale-setup-1.86.2-amd64.msi" 
$msiPath = "$env:TEMP\tailscale-installer.msi"

# CORRECTED: Use ProgramW6432 to always get the 64-bit Program Files path.
$tailscaleExePath = Join-Path -Path $env:ProgramW6432 -ChildPath "Tailscale\tailscale.exe"

# --- Step 2: Download the Tailscale Installer ---
Write-Host "Downloading Tailscale installer from $msiUrl..."
try {
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
    Write-Host "Download complete. Installer saved to $msiPath"
}
catch {
    Write-Error "Failed to download the Tailscale installer. Please check the URL and your internet connection."
    exit
}

# --- Step 3: Install Tailscale Silently ---
Write-Host "Starting silent Tailscale installation..."
Start-Process -FilePath msiexec -ArgumentList "/i", "`"$msiPath`"", "/qn", "TS_NOLAUNCH=1" -Wait
Write-Host "Installation process complete. Verifying installation..."
Restart-Computer -Force
