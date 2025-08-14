<#
.SYNOPSIS
    Configures a Windows machine for kiosk mode by setting auto-login for a specified user
    and replacing the default shell (explorer.exe) with a custom executable.

.DESCRIPTION
    This script performs two main functions:
    1.  Sets registry keys to enable automatic logon for a specified domain user.
    2.  Sets the 'Shell' registry key to launch the specified executable or script instead of the
        standard Windows shell (explorer.exe) for all users. This is a system-wide change.

    The script will prompt you for the password of the kiosk user. It is recommended
    to run this script with elevated privileges (Run as Administrator).

.NOTES
    Author: Gemini
    Date: August 2025
    Requires: Administrative privileges
#>

# -----------------------------------------------------------------------------
#   CONFIGURATION - EDIT THESE VALUES AS NEEDED
# -----------------------------------------------------------------------------

# The username for the auto-login account. This must be an existing user.
$username = "kioskuser"

# The domain name for the user.
# e.g., "mydomain.com" or "MYDOMAIN"
$domainName = "YOUR_DOMAIN_NAME"

# The full path to the executable or PowerShell script you want to run in kiosk mode.
# If you are using a PowerShell script, the exePath will be the command to launch powershell.
$exePath = "C:\Users\Public\Downloads\program.exe"

# The full path to the PowerShell script you want to run.
# This variable is only used if you are launching a script.
# If you are launching an executable directly, you can ignore this variable.
$scriptPath = "C:\path\to\your\script.ps1"

# -----------------------------------------------------------------------------
#   SCRIPT BODY - DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING
# -----------------------------------------------------------------------------

Write-Host "Starting kiosk mode configuration..." -ForegroundColor Green

# Check for administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run with Administrator privileges. Please right-click the script and select 'Run as Administrator'." -ForegroundColor Red
    exit
}

# --- Section 1: Configure Auto-Login ---

Write-Host "Configuring auto-login for user '$username' in domain '$domainName'..." -ForegroundColor Yellow

# Registry path for Winlogon settings
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Check if the registry path exists before trying to create keys
if (-not (Test-Path $winlogonPath)) {
    Write-Host "Error: Winlogon registry path not found. Exiting." -ForegroundColor Red
    exit
}

# Prompt for the user's password securely
$password = Read-Host -Prompt "Please enter the password for '$username'" -AsSecureString

# Set the registry keys for auto-login
# Note: The password is stored in plaintext in the registry.
try {
    Set-ItemProperty -Path $winlogonPath -Name AutoAdminLogon -Value "1" -Force
    Set-ItemProperty -Path $winlogonPath -Name DefaultUserName -Value $username -Force
    Set-ItemProperty -Path $winlogonPath -Name DefaultDomainName -Value $domainName -Force
    Set-ItemProperty -Path $winlogonPath -Name DefaultPassword -Value ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))) -Force
    Write-Host "Auto-login configuration complete." -ForegroundColor Green
}
catch {
    Write-Host "Error configuring auto-login: $_" -ForegroundColor Red
    exit
}


# --- Section 2: Change the System Shell ---

Write-Host "Changing the system shell..." -ForegroundColor Yellow

# Backup the original shell value (explorer.exe) for easy restoration
$originalShell = Get-ItemProperty -Path $winlogonPath -Name Shell -ErrorAction SilentlyContinue
if ($originalShell) {
    Set-ItemProperty -Path $winlogonPath -Name OriginalShell -Value $originalShell.Shell -Force
    Write-Host "Original shell '$($originalShell.Shell)' backed up to the 'OriginalShell' registry key." -ForegroundColor Cyan
}
else {
    Write-Host "Could not find original shell value. Skipping backup." -ForegroundColor Yellow
}

# Set the new shell to the specified program or script
# If using a PowerShell script, the value should be the command to launch powershell.exe with the script.
# Example: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\your\script.ps1"
try {
    # If the path ends with ".ps1", construct the command to run the script.
    if ($exePath -like "*.ps1") {
        $finalShell = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$exePath`""
    }
    # If using the dedicated script variable, construct the command to run that script.
    elseif ($scriptPath -like "*.ps1") {
        $finalShell = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    }
    # Otherwise, assume it's a direct executable.
    else {
        $finalShell = $exePath
    }

    Set-ItemProperty -Path $winlogonPath -Name Shell -Value $finalShell -Force
    Write-Host "Shell successfully set to '$finalShell'." -ForegroundColor Green
}
catch {
    Write-Host "Error setting new shell: $_" -ForegroundColor Red
    exit
}


Write-Host "Kiosk mode setup is complete. Please restart the computer to see the changes." -ForegroundColor Green
Write-Host "To revert the changes, delete the 'DefaultPassword' key and set the 'Shell' key back to 'explorer.exe'." -ForegroundColor White
