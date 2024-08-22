#$computers = Get-ADComputer -Filter * -Properties operatingsystem |Where operatingsystem -match 'Windows' |where {$_.enabled -ne $false} |Sort-Object name
#$Reboots = Get-PendingReboot -Computer $computers.Name |where {$_.RebootPending -eq $true}|select computer, LastReboot, CBServicing, WindowsUpdate, CCMClientSDK | out-file c:\temp\PCPendingReboot.csv

# Get all enabled Windows computers from Active Directory
$computers = Get-ADComputer -Filter {Enabled -eq $true -and OperatingSystem -like "*Windows*"} | Sort-Object Name

# Check for pending reboots on the retrieved computers
$Reboots = Get-PendingReboot -ComputerName $computers.Name | 
           Where-Object { $_.RebootPending -eq $true } | 
           Select-Object Computer, LastReboot, CBServicing, WindowsUpdate, CCMClientSDK

# Output the results to a CSV file
$Reboots | Export-Csv -Path "C:\temp\PCPendingReboot.csv" -NoTypeInformation
