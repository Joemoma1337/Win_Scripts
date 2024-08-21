Get-ADUser -LDAPFilter "(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=2))" | Export-Csv -Path c:\temp\activeusers.csv
