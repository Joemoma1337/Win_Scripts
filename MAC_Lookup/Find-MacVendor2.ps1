# File paths
$inputFile  = "MAC_Input.txt"
$dbFile     = "MAC_VendorDB.csv"
$outputFile = "MAC_Output.csv"

# Load vendor DB into hash table
$vendorDB = @{}
Import-Csv -Path $dbFile | ForEach-Object {
    $macPrefix = $_."Mac Prefix".Replace(":", "").ToUpper()
    $vendorDB[$macPrefix] = $_."Vendor Name"
}

# MAC regex for multiple formats
$macRegex = '([0-9a-fA-F]{2}([-:])){5}[0-9a-fA-F]{2}|([0-9a-fA-F]{4}[.-]){2}[0-9a-fA-F]{4}|([0-9a-fA-F]{2}\.){5}[0-9a-fA-F]{2}'

$results = @()

Get-Content -Path $inputFile | ForEach-Object {
    $line = $_
    if ($line -match $macRegex) {
        $macAddress = $matches[0]
        $cleanMac   = $macAddress -replace '[:\-\.]', ''
        $macPrefix  = $cleanMac.Substring(0,6).ToUpper()

        $vendorName = $vendorDB[$macPrefix]
        if (-not $vendorName) { $vendorName = "Unknown" }

        Write-Host ("{0,-80} {1}" -f $line, $vendorName)

        $results += [PSCustomObject]@{
            "Original Line" = $line.Trim()
            "Vendor"        = $vendorName
        }
    }
    else {
        Write-Host ("{0,-80} {1}" -f $line, "N/A")
        $results += [PSCustomObject]@{
            "Original Line" = $line.Trim()
            "Vendor"        = "N/A"
        }
    }
}

$results | Export-Csv -Path $outputFile -NoTypeInformation
Write-Host "`nProcessing complete. Results saved to $outputFile"
