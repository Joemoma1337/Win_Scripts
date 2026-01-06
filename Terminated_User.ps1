# --- CONFIGURATION ---
$userFile = "C:\temp\users.txt"
$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_()=+"

# --- PREREQUISITES & LOGIN ---
# This will prompt for a web-based login once at the start.
# Required Scopes: User.ReadWrite.All, Directory.ReadWrite.All, UserAuthenticationMethod.ReadWrite.All
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "UserAuthenticationMethod.ReadWrite.All"

if (Test-Path $userFile) {
    $samAccounts = Get-Content $userFile

    foreach ($user in $samAccounts) {
        Write-Host "`n--- Processing Termination for: $user ---" -ForegroundColor Blue
        
        # Generate a unique 32-character password
        $newPassword = -join ((1..32) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

        try {
            # 1. LOCAL ACTIVE DIRECTORY ACTIONS
            # ---------------------------------------------------------
            Write-Host "[1/5] Updating Local AD..." -NoNewline
            Set-ADAccountPassword -Identity $user -NewPassword (ConvertTo-SecureString $newPassword -AsPlainText -Force) -ErrorAction Stop
            Disable-ADAccount -Identity $user
            Write-Host " DONE" -ForegroundColor Green

            # 2. ENTRA ID (OFFICE 365) ACTIONS
            # ---------------------------------------------------------
            # Note: We assume $user is the UPN (e.g. user@domain.com)
            
            # Reset Cloud Password & Disable Account
            Write-Host "[2/5] Blocking Cloud Sign-in..." -NoNewline
            Update-MgUser -UserId $user -AccountEnabled:$false -PasswordProfile @{
                Password = $newPassword
                ForceChangePasswordNextSignIn = $false
            } -ErrorAction Stop
            Write-Host " DONE" -ForegroundColor Green

            # Revoke Sessions (Kicks user out of Teams/Outlook)
            Write-Host "[3/5] Revoking active sessions..." -NoNewline
            Revoke-MgUserSignInSession -UserId $user -ErrorAction SilentlyContinue
            Write-Host " DONE" -ForegroundColor Green

            # Clear MFA Methods (Phones, Authenticator Apps)
            Write-Host "[4/5] Clearing MFA methods..." -NoNewline
            $methods = Get-MgUserAuthenticationMethod -UserId $user -ErrorAction SilentlyContinue
            foreach ($method in $methods) {
                # We skip 'softwareOath' sometimes as it can be system-managed, but try to delete all
                Remove-MgUserAuthenticationMethod -UserId $user -AuthenticationMethodId $method.Id -ErrorAction SilentlyContinue
            }
            Write-Host " DONE" -ForegroundColor Green

            # 3. OPTIONAL: REMOVE LICENSES
            # ---------------------------------------------------------
            Write-Host "[5/5] Removing M365 Licenses..." -NoNewline
            $userObj = Get-MgUser -UserId $user -Property AssignedLicenses
            foreach ($lic in $userObj.AssignedLicenses) {
                Set-MgUserLicense -UserId $user -RemoveLicenses @($lic.SkuId) -AddLicenses @() -ErrorAction SilentlyContinue
            }
            Write-Host " DONE" -ForegroundColor Green

            Write-Host "SUCCESS: $user has been fully offboarded." -ForegroundColor Green
        }
        catch {
            Write-Warning "FAILED to fully process $user. Reason: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Error "The file $userFile was not found."
}

# --- CLEANUP ---
# Disconnect-MgGraph # Uncomment if you want to sign out at the end
