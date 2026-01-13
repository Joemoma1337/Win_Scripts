<#
.SYNOPSIS
    Queries multiple servers simultaneously for pending reboot status.
.DESCRIPTION
    Uses Invoke-Command with a custom ThrottleLimit to check registry keys 
    associated with Windows Update, CBS, and SCCM pending reboots.
#>

# --- Configuration ---
$ConcurrencyLimit = 50           # Adjust this to change simultaneous queries
$ExportPath       = "C:\temp\servers_pending_reboot.csv"

# 1. Get enabled Windows Servers (Filtered at the AD source for speed)
Write-Host "Retrieving server list from Active Directory..." -ForegroundColor Cyan
$ServerNames = Get-ADComputer -Filter 'OperatingSystem -like "*Server*" -and Enabled -eq $true' | 
               Select-Object -ExpandProperty Name

if (-not $ServerNames) { 
    Write-Warning "No servers found. Exiting."
    return 
}

# 2. Parallel execution using the ThrottleLimit
Write-Host "Checking $($ServerNames.Count) servers (Simultaneous: $ConcurrencyLimit)..." -ForegroundColor Cyan



$Results = Invoke-Command -ComputerName $ServerNames -ThrottleLimit $ConcurrencyLimit -ErrorAction SilentlyContinue -ScriptBlock {
    # This block runs on the remote servers
    $Status = @{
        Computer      = $env:COMPUTERNAME
        CBServicing   = $false
        WindowsUpdate = $false
        CCMClient     = $false
        RebootPending = $false
    }

    # Check Registry for Component Based Servicing
    if (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $Status.CBServicing = $true
    }

    # Check Registry for Windows Update
    if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
        $Status.WindowsUpdate = $true
    }

    # Check Registry for SCCM Client
    if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\RebootManagement\RebootSignal" -ErrorAction SilentlyContinue) {
        $Status.CCMClient = $true
    }

    # If any are true, a reboot is pending
    if ($Status.CBServicing -or $Status.WindowsUpdate -or $Status.CCMClient) {
        $Status.RebootPending = $true
    }

    return [PSCustomObject]$Status
}

# 3. Filter and Export
$PendingOnly = $Results | Where-Object { $_.RebootPending -eq $true }

if ($PendingOnly) {
    $PendingOnly | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "Success! Found $($PendingOnly.Count) servers needing reboot. Report saved to $ExportPath" -ForegroundColor Green
} else {
    Write-Host "No pending reboots detected." -ForegroundColor Yellow
}
