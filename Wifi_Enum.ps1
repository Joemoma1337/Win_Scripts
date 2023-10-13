#Network Name + Password
#(netsh wlan show profiles) | Select-String "All User Profile" | ForEach-Object { $profileName = $_ -replace '.*:\s', ''; $password = (netsh wlan show profile name="$profileName" key=clear | Select-String "Key Content").Line -replace 'Key Content\s+:\s', ''; Write-Host ($profileName.PadRight(20) + $password) }

#Network Name only
#netsh wlan show profiles|Select-String "All User Profile"|ForEach-Object {$ProfileName=$_ -replace '.*:'; echo $ProfileName}

#Network Password only
#(netsh wlan show profiles) | Select-String "All User Profile" | ForEach-Object { $profileName = $_ -replace '.*:\s', ''; ($password = (netsh wlan show profile name="$profileName" key=clear | Select-String "Key Content").Line -replace 'Key Content\s+:\s', '').Trim() } | Where-Object { $_ -ne '' }
