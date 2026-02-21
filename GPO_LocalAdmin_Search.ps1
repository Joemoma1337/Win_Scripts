Import-Module GroupPolicy
Import-Module ActiveDirectory

$gpoList = Get-GPO -All
$finalAudit = @()
$csvPath = "$env:USERPROFILE\Desktop\GPO_Deep_Audit_$(Get-Date -Format 'yyyy-MM-dd').csv"

Write-Host "Analyzing GPO links via AD Attribute Search..." -ForegroundColor Cyan

foreach ($g in $gpoList) {
    try {
        $rawString = Get-GPOReport -Guid $g.Id -ReportType Xml
        $gpoXml = [xml]$rawString
        
        $ns = New-Object System.Xml.XmlNamespaceManager($gpoXml.NameTable)
        $ns.AddNamespace("q1", "http://www.microsoft.com/GroupPolicy/Settings/Security")

        $nodes = $gpoXml.SelectNodes("//q1:RestrictedGroups", $ns)

        if ($nodes.Count -gt 0) {
            foreach ($n in $nodes) {
                $gName = $n.GroupName.Name.'#text'
                
                if ($gName -like "*Administrators*" -or $n.GroupName.SID -eq "S-1-5-32-544") {
                    
                    # 1. Expand Users and Track Source
                    $rawMembers = @($n.Member.Name.'#text')
                    $resolvedUsers = foreach ($member in $rawMembers) {
                        $samName = if ($member -like "*\*") { $member.Split('\')[-1] } else { $member }
                        try {
                            $adObj = Get-ADUser -Filter "SamAccountName -eq '$samName'" -ErrorAction SilentlyContinue
                            if ($null -eq $adObj) {
                                # If not a user, check if it's a group
                                $groupObj = Get-ADGroup -Filter "SamAccountName -eq '$samName'" -ErrorAction SilentlyContinue
                                if ($groupObj) {
                                    # Get members and attach the source group name to each
                                    Get-ADGroupMember -Identity $groupObj.DistinguishedName -Recursive | Select-Object SamAccountName, @{Name="SourceGroup"; Expression={$groupObj.Name}}
                                } else { 
                                    [PSCustomObject]@{ SamAccountName = $member; SourceGroup = "Direct Member" }
                                }
                            } else { 
                                [PSCustomObject]@{ SamAccountName = $member; SourceGroup = "Direct Member" }
                            }
                        } catch { 
                            [PSCustomObject]@{ SamAccountName = $member; SourceGroup = "Unknown/Error" }
                        }
                    }

                    # 2. Find Linked Containers by GPO GUID
                    $gpoGuid = $g.Id.ToString()
                    $containers = Get-ADObject -Filter "gPLink -like '*$gpoGuid*'" -Properties gPLink, DistinguishedName
                    
                    $computersFound = foreach ($container in $containers) {
                        Get-ADComputer -Filter 'Enabled -eq $true' -SearchBase $container.DistinguishedName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                    }

                    # 3. Build Results
                    # We use -Unique on SamAccountName to keep the list clean
                    foreach ($userData in ($resolvedUsers | Sort-Object SamAccountName -Unique)) {
                        foreach ($comp in ($computersFound | Select-Object -Unique)) {
                            $finalAudit += [PSCustomObject]@{
                                GPOName         = $g.DisplayName
                                RestrictedGroup = $gName
                                ResolvedUser    = $userData.SamAccountName
                                UserSourceGroup = $userData.SourceGroup
                                TargetComputer  = $comp
                                LinkedOU        = $containers.DistinguishedName -join " | "
                            }
                        }
                    }
                }
            }
        }
    } catch { continue }
}

if ($finalAudit) {
    $finalAudit | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    $finalAudit | Format-Table -AutoSize
    Write-Host "Success! Check your desktop for the CSV." -ForegroundColor Green
} else {
    Write-Host "Still no mappings found." -ForegroundColor Yellow
}
