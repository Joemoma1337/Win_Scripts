<#
.SYNOPSIS
    Generates a CSV list of all Domain Controllers and their primary IP addresses.

.DESCRIPTION
    1. Retrieves all Domain Controllers from the current domain.
    2. Resolves the Hostname to an IP Address using modern DNS resolution.
    3. Exports the Name and IP to a UTF8 encoded CSV file.
#>

# Ensure the output directory exists
$Path = "C:\temp\ControllersList.csv"
$Dir = Split-Path $Path
if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }

# Get DCs and resolve IPs in a single pipeline
Get-ADDomainController -Filter * | Select-Object Name, 
    @{Name="IPAddress"; Expression={
        # Resolve-DnsName is more reliable than the legacy .NET GetHostByName
        (Resolve-DnsName -Name $_.Name -Type A -ErrorAction SilentlyContinue).IPAddress | Select-Object -First 1
    }} | 
    Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8

Write-Host "Export complete: $Path" -ForegroundColor Cyan
