# Requires the Active Directory module for PowerShell
# If not already imported, you might need to run: Import-Module ActiveDirectory

try {
    Write-Host "Starting server enumeration and local administrator discovery..."

    # Define output paths to the script's current directory
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $currentScriptDir = (Get-Location).Path # Get the directory where the script is run from
    $serverListPath = Join-Path $currentScriptDir "ServerHostnames_$timestamp.txt"
    $localAdminsReportPath = Join-Path $currentScriptDir "LocalAdministratorsReport_$timestamp.csv"

    # Initialize counters and lists
    $serverCount = 0
    $serversToProcess = @()
    $localAdminResults = @() # To store all results for CSV export

    # 1. Get the SID of the "Domain Controllers" group first
    Write-Host "Retrieving SID for 'Domain Controllers' group..."
    $domainControllersGroupSID = (Get-ADGroup -Identity "Domain Controllers" -Properties SID).SID.Value
    if (-not $domainControllersGroupSID) {
        Write-Warning "Could not find 'Domain Controllers' group or retrieve its SID. Domain controllers might not be included."
    }

    # 2. Construct the filter string dynamically
    $filterString = "OperatingSystem -like '*Server*'"
    if ($domainControllersGroupSID) {
        $filterString += " -or PrimaryGroupID -eq '$domainControllersGroupSID'"
    }

    Write-Host "Enumerating servers from Active Directory..."
    Get-ADComputer -Filter $filterString -Properties Name, OperatingSystem |
    Where-Object { $_.Name } | # Ensure the Name property exists and is not null
    Sort-Object Name | # Sorts the objects by Name before outputting
    ForEach-Object {
        $hostname = $_.Name
        Write-Host "  Found server: $hostname"
        $hostname | Out-File -FilePath $serverListPath -Append # Append to file
        $serversToProcess += $hostname # Add to list for later processing
        $serverCount++
    }

    Write-Host "`nFinished enumerating servers. Total servers found: $serverCount."
    Write-Host "Server list saved to: $serverListPath"

    if ($serverCount -eq 0) {
        Write-Warning "No servers found to process for local administrators. Exiting."
        exit
    }

    Write-Host "`nStarting local administrator enumeration for $serverCount servers..."

    foreach ($server in $serversToProcess) {
        Write-Host "`n--- Processing server: $($server) ---"
        try {
            # Test connection first (optional, but good for skipping unreachable hosts quickly)
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
                Write-Warning "  Server '$($server)' is unreachable via ping. Skipping local admin check."
                $localAdminResults += [PSCustomObject]@{
                    ComputerName        = $server
                    SAMAccountName      = "N/A"
                    DisplayName         = "N/A"
                    MemberType          = "N/A"
                    PrincipalSource     = "N/A"
                    ParentADGroup       = "N/A"
                    Status              = "Unreachable"
                    ErrorMessage        = "Server ping failed"
                }
                continue
            }

            # Use Invoke-Command to run Get-LocalGroupMember remotely
            $localAdmins = Invoke-Command -ComputerName $server -ScriptBlock {
                try {
                    Get-LocalGroupMember -Group "Administrators"
                }
                catch {
                    throw "$($_.Exception.Message)"
                }
            } -ErrorAction Stop

            if ($localAdmins) {
                Write-Host "  Local Administrators on $($server):"
                foreach ($admin in $localAdmins) {
                    # Initialize default values for AD-specific properties
                    $memberSamAccountName = "N/A"
                    $memberDisplayName = "N/A"
                    $memberType = $admin.ObjectClass
                    $principalSource = $admin.PrincipalSource
                    $parentADGroupName = "N/A"

                    # Add directly if it's a user or a local group
                    if ($admin.ObjectClass -eq 'User' -or $admin.PrincipalSource -eq 'Local') {
                        # For local users/groups, SAMAccountName and DisplayName might just be their Name
                        $memberSamAccountName = $admin.Name
                        $memberDisplayName = $admin.Name # Or populate as needed if local objects have a different DisplayName
                        Write-Host "    - $($admin.Name) (Type: $($memberType), Source: $($principalSource))"

                        $localAdminResults += [PSCustomObject]@{
                            ComputerName        = $server
                            SAMAccountName      = $memberSamAccountName
                            DisplayName         = $memberDisplayName
                            MemberType          = $memberType
                            PrincipalSource     = $principalSource
                            ParentADGroup       = $parentADGroupName
                            Status              = "Success"
                            ErrorMessage        = ""
                        }
                    }
                    # If it's an AD Group, enumerate its members
                    elseif ($admin.ObjectClass -eq 'Group' -and $admin.PrincipalSource -eq 'ActiveDirectory') {
                        $adGroupNameOnly = ($admin.Name -split '\\')[-1]
                        $parentADGroupName = $admin.Name # Store the original full name for the report

                        Write-Host "    - $($admin.Name) (Type: $($memberType), Source: $($principalSource)) -- Enumerating members of '$($adGroupNameOnly)'..."
                        try {
                            # Get members of the AD group, recursively for nested groups
                            # Pipe to Get-ADObject to get SAMAccountName and DisplayName
                            $adGroupMembers = Get-ADGroupMember -Identity $adGroupNameOnly -Recursive -ErrorAction Stop | Select-Object -ExpandProperty DistinguishedName | ForEach-Object {
                                # Determine object class and fetch appropriate AD object
                                # This ensures we get the right properties for users, groups, and computers
                                $adObject = $null
                                $objError = ""
                                try {
                                    $adObject = Get-ADObject -Identity $_ -Properties samAccountName, DisplayName, objectClass -ErrorAction Stop
                                } catch {
                                    $objError = $_.Exception.Message
                                    # Fallback if Get-ADObject fails for a specific member
                                    # Attempt to extract SAMAccountName from DN if available
                                    $fallbackSam = ""
                                    if ($_ -match 'CN=([^,]+)') {
                                        $fallbackSam = $matches[1]
                                    }
                                    return [PSCustomObject]@{
                                        SAMAccountName = $fallbackSam;
                                        DisplayName = $fallbackSam;
                                        ObjectClass = 'Unknown';
                                        ErrorDetail = $objError
                                    }
                                }

                                # Ensure properties exist or set to N/A
                                $sam = $adObject.SAMAccountName
                                $display = $adObject.DisplayName
                                $objClass = $adObject.ObjectClass

                                # If DisplayName is empty for a user, use their Name
                                if ($objClass -eq 'user' -and [string]::IsNullOrWhiteSpace($display)) {
                                    $display = $adObject.Name
                                }
                                # If DisplayName is empty for a group/computer, use SAMAccountName
                                elseif ([string]::IsNullOrWhiteSpace($display)) {
                                    $display = $sam
                                }

                                [PSCustomObject]@{
                                    SAMAccountName = $sam;
                                    DisplayName = $display;
                                    ObjectClass = $objClass;
                                    ErrorDetail = $objError
                                }
                            }

                            if ($adGroupMembers) {
                                foreach ($member in $adGroupMembers) {
                                    Write-Host "      --> $($member.DisplayName) (SAM: $($member.SAMAccountName), Type: $($member.ObjectClass))"
                                    $localAdminResults += [PSCustomObject]@{
                                        ComputerName        = $server
                                        SAMAccountName      = $member.SAMAccountName
                                        DisplayName         = $member.DisplayName
                                        MemberType          = $member.ObjectClass
                                        PrincipalSource     = "ActiveDirectory"
                                        ParentADGroup       = $parentADGroupName
                                        Status              = "Success"
                                        ErrorMessage        = $member.ErrorDetail
                                    }
                                }
                            } else {
                                Write-Warning "      No members found for AD group '$($admin.Name)'."
                                $localAdminResults += [PSCustomObject]@{
                                    ComputerName        = $server
                                    SAMAccountName      = "N/A"
                                    DisplayName         = "N/A"
                                    MemberType          = $admin.ObjectClass
                                    PrincipalSource     = $admin.PrincipalSource
                                    ParentADGroup       = $parentADGroupName
                                    Status              = "Success (No Members)"
                                    ErrorMessage        = "AD Group has no members"
                                }
                            }
                        }
                        catch {
                            # Capture the error specific to this AD group lookup
                            Write-Error "      Error enumerating members for AD group '$($admin.Name)': $($_.Exception.Message)"
                            $localAdminResults += [PSCustomObject]@{
                                ComputerName        = $server
                                SAMAccountName      = "N/A"
                                DisplayName         = "N/A"
                                MemberType          = $admin.ObjectClass
                                PrincipalSource     = $admin.PrincipalSource
                                ParentADGroup       = $parentADGroupName
                                Status              = "Failed (AD Group Members)"
                                ErrorMessage        = "$($_.Exception.Message)"
                            }
                        }
                    }
                }
            } else {
                Write-Warning "  No members found in the local Administrators group on $($server) (or access denied or group is empty)."
                 $localAdminResults += [PSCustomObject]@{
                    ComputerName        = $server
                    SAMAccountName      = "N/A"
                    DisplayName         = "N/A"
                    MemberType          = "N/A"
                    PrincipalSource     = "N/A"
                    ParentADGroup       = "N/A"
                    Status              = "No Members Found/Access Denied"
                    ErrorMessage        = "Could not retrieve members or group is empty"
                }
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Error "  Failed to enumerate local administrators on $($server): $($errorMessage)"
            $localAdminResults += [PSCustomObject]@{
                ComputerName        = $server
                SAMAccountName      = "N/A"
                DisplayName         = "N/A"
                MemberType          = "N/A"
                PrincipalSource     = "N/A"
                ParentADGroup       = "N/A"
                Status              = "Failed"
                ErrorMessage        = $errorMessage
            }
        }
    }

    Write-Host "`n--- Local Administrator Enumeration Complete ---"
    Write-Host "Total servers processed: $($serversToProcess.Count)"
    Write-Host "Detailed report saved to: $localAdminsReportPath"

    # Export all results to CSV - APPLYING COLUMN ORDER HERE
    $localAdminResults | Select-Object ComputerName, SAMAccountName, DisplayName, MemberType, PrincipalSource, ParentADGroup, Status, ErrorMessage | Export-Csv -Path $localAdminsReportPath -NoTypeInformation -Encoding UTF8

}
catch {
    Write-Error "A critical error occurred during script execution: $($_.Exception.Message)"
    Write-Error "Please ensure the Active Directory module is installed, PowerShell Remoting is enabled on target servers, and you have appropriate permissions."
}
