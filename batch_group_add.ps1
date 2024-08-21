Import-Csv -Path “C:\Temp\input.csv” | ForEach-Object {Add-ADGroupMember -Identity “destination_group” -Members $_.’SamAccountName’}
