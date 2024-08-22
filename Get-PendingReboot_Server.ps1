# Get all Windows Server computers in AD
$servers = Get-ADComputer -Filter 'operatingsystem -like "*Server*"' -Properties operatingsystem | Where-Object {$_.enabled -eq $true} | Sort-Object name

# Get pending reboots for these servers
$Reboots = Get-PendingReboot -ComputerName $servers.Name | Where-Object {$_.RebootPending -eq $true} | 
    Select-Object Computer, LastReboot, CBServicing, WindowsUpdate, CCMClientSDK

# Export the results to a CSV file
$Reboots | Export-Csv -Path 'c:\temp\servers_pending_reboot.csv' -NoTypeInformation
