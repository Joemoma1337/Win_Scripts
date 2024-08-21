param (
	[string[]]$Hostname
)
foreach ($i in $Hostname) {
	Write-Output $i
	query user /server:$i | Select-String -Pattern "USERNAME|disc"
	Write-Output ""
}
