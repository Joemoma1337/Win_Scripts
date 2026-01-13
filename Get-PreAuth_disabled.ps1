# 1. Filter at the source: Only request users where the attribute is true.
# This is significantly faster and uses less memory.
$usersWithPreAuthDisabled = Get-ADUser -Filter 'DoesNotRequirePreAuth -eq $true' | Select-Object -ExpandProperty SamAccountName

# 2. Output the results
if ($usersWithPreAuthDisabled) {
    Write-Host "Usernames of accounts where DoesNotRequirePreAuth is true:" -ForegroundColor Cyan
    $usersWithPreAuthDisabled
} else {
    Write-Host "No accounts found with PreAuth disabled." -ForegroundColor Yellow
}
