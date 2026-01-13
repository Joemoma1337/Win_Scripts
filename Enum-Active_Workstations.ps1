Get-ADComputer -Filter {(OperatingSystem -Notlike "*windows*server*") -and (Enabled -eq "True")} -Properties OperatingSystem, OperatingSystemVersion | 
    Select-Object DNSHostName, OperatingSystem, OperatingSystemVersion | 
    Export-Csv -Path "C:\temp\all_non_server_endpoints.csv" -NoTypeInformation
