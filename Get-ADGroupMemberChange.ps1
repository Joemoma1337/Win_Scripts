$events = Get-EventLog -LogName Security -InstanceId 4728 -Newest 100 | Where-Object { $_.ReplacementStrings -like "*Test_Group*" }
#Get-EventLog -LogName Security -InstanceId 4728 -Newest 100 | Where-Object { $_.ReplacementStrings -like "*Test_Group*" } | Format-List *
foreach ($event in $events) {
    $event | Select-Object TimeGenerated, @{Name="Actor";Expression={$_.ReplacementStrings[6]}}, @{Name="Target";Expression={$_.ReplacementStrings[0]}}, @{Name="Group";Expression={$_.ReplacementStrings[2]}} | Format-List
    Write-Host "===================="  # Blank line for readability
}
