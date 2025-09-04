<#
    .SYNOPSIS
    Creates a new local user and configures the system for automatic login
    for that user.

    .DESCRIPTION
    This script performs two primary functions:
    1. Creates a new local user account with a provided username and password.
    2. Modifies the Windows Registry to enable and configure automatic login
       on system startup using the new user's credentials.

    .NOTES
    - This script requires Administrator privileges to run. It will check and
      prompt for elevation if not run as an administrator.
    - Enabling automatic login stores the user's password in the registry
      in plain text. This is a potential security risk and should only be
      used in secure, controlled environments.
    - The new user is created and added to the 'Users' group by default.
#>

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
