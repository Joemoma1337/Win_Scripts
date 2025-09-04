# --- Configuration Section ---
# Update these variables with the desired username, password, and system.
$userName = "AutoUser"
$userPassword = "StrongPassword123" # CHANGE THIS to a secure password
$computerName = $env:COMPUTERNAME # Automatically gets the current computer name

# --- Elevation Check ---
# Checks if the script is running with Administrator privileges.
# If not, it re-runs the script with elevation.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script needs to be run as an Administrator. Re-starting with elevated privileges..."
    Start-Process powershell.exe -ArgumentList "-File", "`"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Step 1: Create the new local user ---
Write-Host "Creating local user account '$userName'..."
try {
    # Convert the plain text password to a SecureString object as required by New-LocalUser
    $securePassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
    
    # Check if the user already exists to avoid errors
    if (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue) {
        Write-Warning "User '$userName' already exists. Skipping user creation."
    } else {
        New-LocalUser -Name $userName -Password $securePassword -PasswordNeverExpires -UserMayNotChangePassword -AccountExpires (Get-Date).AddYears(100)
        Write-Host "User '$userName' created successfully."
    }
} catch {
    Write-Error "Failed to create user '$userName'. Error: $_"
    exit
}

# --- Step 2: Configure the Registry for Auto-Login ---
# The registry keys for auto-login are located under the Winlogon subkey.
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

Write-Host "Configuring registry for automatic login for '$userName'..."
try {
    # Set the AutoAdminLogon to '1' to enable automatic login.
    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
    
    # Set the DefaultUserName to the new user's account name.
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Type String -Force
    
    # Set the DefaultPassword to the user's password.
    Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $userPassword -Type String -Force
    
    # Set the DefaultDomainName to the local computer name.
    # Note: On a local machine, the domain is the computer name.
    Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $computerName -Type String -Force
    
    Write-Host "Registry successfully configured for auto-login."
    Write-Host "The system will now automatically log in as '$userName' on the next restart."
} catch {
    Write-Error "Failed to configure registry settings for auto-login. Error: $_"
    exit
}

Write-Host "Script finished."
Write-Host "The system will log in as '$userName' on its next restart."

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
