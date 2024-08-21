#for use syntax: .\Get-Disconnected.ps1 -Hostname <hostname>
#param (
#	[string[]]$Hostname
#)

$Hostname = @("hostname1") #comment out if using param
foreach ($i in $Hostname) {
	Write-Output $i
	query user /server:$i | Select-String -Pattern "USERNAME|disc"
	Write-Output ""
}
