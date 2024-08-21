$events = Get-EventLog -LogName Security -InstanceId 4625 -Newest 10 | fortmat-list
#Get-EventLog -LogName Security -InstanceId 4625 -Newest 10
foreach ($event in $events) {
    $event | Select-Object TimeGenerated, @{Name="Hostname";Expression={$_.ReplacementStrings[1]}}, @{Name="Target";Expression={$_.ReplacementStrings[5]}}| Format-List
    Write-Host "===================="  # Blank line for readability
}
