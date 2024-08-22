#Get-MsolUser -All | select DisplayName -ExpandProperty StrongAuthenticationUserDetails | ft DisplayName, PhoneNumber, Email | out-file c:\temp\authenticationmethods.csv

# Retrieve all users with StrongAuthenticationUserDetails, select the relevant properties, and export to CSV
Get-MsolUser -All | 
    Select-Object DisplayName, @{Name="PhoneNumber";Expression={$_.StrongAuthenticationUserDetails.PhoneNumber}}, 
                              @{Name="Email";Expression={$_.StrongAuthenticationUserDetails.Email}} | 
    Export-Csv -Path 'c:\temp\authenticationmethods.csv' -NoTypeInformation
