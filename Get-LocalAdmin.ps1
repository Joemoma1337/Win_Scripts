<#
.SYNOPSIS
    Discovery of local administrators across domain servers using parallel processing.
    
.DESCRIPTION
    1. Enumerates all Windows Servers from Active Directory.
    2. Uses Invoke-Command with a custom ThrottleLimit to query servers in parallel.
    3. Identifies local users and Active Directory groups in the local 'Administrators' group.
    4. Recursively expands AD groups to list individual members.
    5. Exports a comprehensive CSV report.

.NOTES
    Author: Gemini Optimized
    Version: 2.0
#>

# --- Configuration ---
$ConcurrencyLimit = 50           # Number of servers to query simultaneously
$ExportFolder     = "C:\temp"    # Where the results will be saved
$Timestamp        = Get-Date -Format 'yyyyMMdd_HHmmss'
$ReportPath       = Join-Path $ExportFolder "LocalAdminsReport_$Timestamp.csv"
$ServerListPath   = Join-Path $ExportFolder "ServerList_$Timestamp.txt"

try {
    # Ensure Export Directory Exists
    if (-not (Test-Path $ExportFolder)) { New-Item -ItemType Directory -Path $ExportFolder | Out-Null }

    Write-Host "--- Starting Parallel Admin Audit (Throttle: $ConcurrencyLimit) ---" -ForegroundColor Cyan

    # 1. Enumerate Servers from Active Directory
    Write-Host "[1/4] Querying Active Directory for Server list..." -NoNewline
    $dcGroupSID = (Get-ADGroup -Identity "Domain Controllers").SID.Value
    $adFilter = "OperatingSystem -like '*Server*' -or PrimaryGroupID -eq '$dcGroupSID'"
    
    $servers = Get-ADComputer -Filter $adFilter | Select-Object -ExpandProperty Name | Sort-Object
    
    if ($null -eq $servers) { 
        Write-Error "No servers found in Active Directory. Exiting."
        return 
    }
    Write-Host " Done. ($($servers.Count) servers found)" -ForegroundColor Green
    $servers | Out-File -FilePath $ServerListPath

    # 2. Parallel Query via Invoke-Command
    Write-Host "[2/4] Querying local 'Administrators' groups in parallel..."
    $results = Invoke-Command -ComputerName $servers -ThrottleLimit $ConcurrencyLimit -ErrorAction SilentlyContinue -ScriptBlock {
        try {
            # Query the local group
            $members = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
            foreach ($m in $members) {
                [PSCustomObject]@{
                    ComputerName    = $env:COMPUTERNAME
                    MemberName      = $m.Name
                    MemberType      = $m.ObjectClass
                    PrincipalSource = $m.PrincipalSource
                    Status          = "Success"
                    ErrorDetail     = ""
                }
            }
        } catch {
            [PSCustomObject]@{
                ComputerName    = $env:COMPUTERNAME
                MemberName      = "N/A"
                MemberType      = "N/A"
                PrincipalSource = "N/A"
                Status          = "Connection Failed"
                ErrorDetail     = $_.Exception.Message
            }
        }
    }

    # 3. Post-Processing: Recursive AD Group Expansion
    Write-Host "[3/4] Processing results and expanding AD Groups..."
    $finalReport = foreach ($entry in $results) {
        # If the member is an AD Group, expand it locally to avoid multiple remote hops
        if ($entry.MemberType -eq 'Group' -and $entry.PrincipalSource -eq 'ActiveDirectory') {
            try {
                $groupName = ($entry.MemberName -split '\\')[-1]
                $adMembers = Get-ADGroupMember -Identity $groupName -Recursive -ErrorAction Stop
                
                foreach ($user in $adMembers) {
                    [PSCustomObject]@{
                        ComputerName    = $entry.ComputerName
                        SAMAccountName  = $user.samAccountName
                        DisplayName     = $user.name
                        MemberType      = $user.objectClass
                        PrincipalSource = "ActiveDirectory"
                        ParentADGroup   = $entry.MemberName
                        Status          = "Success"
                        ErrorMessage    = ""
                    }
                }
            } catch {
                # Fallback if group expansion fails (e.g., group not found or permissions)
                $entry | Select-Object ComputerName, 
                    @{N="SAMAccountName";E={"N/A"}}, 
                    @{N="DisplayName";E={"N/A"}}, 
                    MemberType, PrincipalSource, 
                    @{N="ParentADGroup";E={$entry.MemberName}}, 
                    @{N="Status";E={"Expansion Failed"}}, 
                    @{N="ErrorMessage";E={$_.Exception.Message}}
            }
        } else {
            # It's a local user or a single AD user added directly
            $entry | Select-Object ComputerName, 
                @{N="SAMAccountName";E={$entry.MemberName}}, 
                @{N="DisplayName";E={$entry.MemberName}}, 
                MemberType, PrincipalSource, 
                @{N="ParentADGroup";E={"N/A"}}, 
                Status, 
                @{N="ErrorMessage";E={$entry.ErrorDetail}}
        }
    }

    # 4. Final Export
    Write-Host "[4/4] Exporting final report to CSV..."
    $finalReport | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "`nAudit Complete!" -ForegroundColor Green
    Write-Host "Report: $ReportPath"
    Write-Host "Server List: $ServerListPath"

} catch {
    Write-Error "A critical error occurred: $($_.Exception.Message)"
}
