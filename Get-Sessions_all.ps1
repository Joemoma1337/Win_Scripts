#for use syntax: .\Get-Disconnected.ps1 -Hostname <hostname>
#param (
#	[string[]]$Hostname
#)

$Hostname = @("WIN-JRECMT6ND0T") #comment out if using param
foreach ($i in $Hostname) {
	Write-Output $i
	query user /server:$i
	Write-Output ""
}
