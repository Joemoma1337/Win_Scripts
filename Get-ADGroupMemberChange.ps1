<#
.SYNOPSIS
    Tracks membership additions to a specific Active Directory group.

.DESCRIPTION
    This script searches the Security Event Log for Event ID 4728 (Member Added to Global Group).
    It filters for a specific group name and parses the "ReplacementStrings" (raw data properties)
    to identify:
    1. The Time the change occurred.
    2. The "Actor" (The administrator or system account that performed the action).
    3. The "Target" (The user who was added to the group).
    4. The "Group" (The name of the security group that was modified).

.NOTES
    Event ID 4728 Mapping Key:
    [0] - Target User (The person added)
    [2] - Group Name
    [6] - Actor (The person who did the adding)
#>

# 1. Fetch the 100 most recent group-addition events (ID 4728) from the Security log.
# 2. Filter those events to find only those where the Group Name contains "Test_Group".
$events = Get-EventLog -LogName Security -InstanceId 4728 -Newest 100 | Where-Object { 
    $_.ReplacementStrings -like "*Test_Group*" 
}

# Iterate through each event found to format the raw data into a readable list.
foreach ($event in $events) {
    $event | Select-Object TimeGenerated, 
        # Extract the 'Actor' (Index 6 in the raw data array)
        @{Name="Actor";  Expression={$_.ReplacementStrings[6]}}, 
        
        # Extract the 'Target' (Index 0 in the raw data array)
        @{Name="Target"; Expression={$_.ReplacementStrings[0]}}, 
        
        # Extract the 'Group' (Index 2 in the raw data array)
        @{Name="Group";  Expression={$_.ReplacementStrings[2]}} | 
        Format-List
    
    # Visual separator for multi-event output
    Write-Host "====================" 
}
