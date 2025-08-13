# MAC syntax needs to be one of the following:
# 20.88.10.a1.b2.c3
# 08-92-04-a1-b2-c3
# 6c3c-8ca1-b2c3
# 2088.10a1.b2c3

#Vendor database download from here: https://maclookup.app/downloads/csv-database

# Define file paths
$inputFile = "MAC_Input.txt"
$dbFile = "MAC_VendorDB.csv"
$outputFile = "MAC_Output.csv"

# Load the vendor database into a hash table for fast lookups
$vendorDB = @{}
Import-Csv -Path $dbFile | ForEach-Object {
    # The MAC prefix is the first 6 characters of the MAC address,
    # so we'll store the vendor by a clean, separator-free prefix.
    $macPrefix = $_."Mac Prefix".Replace(":", "")
    $vendorDB[$macPrefix] = $_."Vendor Name"
}

# Process the input file
$results = @()
Get-Content -Path $inputFile | ForEach-Object {
    $line = $_

    # A more flexible regular expression to match different MAC address formats.
    # It will match any combination of hex characters separated by ':', '-', or '.'
    # and also the Cisco-style format (aabb.ccdd.eeff).
    $macRegex = '([0-9a-fA-F]{2}(?:[:-])[0-9a-fA-F]{2}(?:[:-])[0-9a-fA-F]{2}(?:[:-])[0-9a-fA-F]{2}(?:[:-])[0-9a-fA-F]{2}(?:[:-])[0-9a-fA-F]{2})|([0-9a-fA-F]{4}(?:[.-])[0-9a-fA-F]{4}(?:[.-])[0-9a-fA-F]{4})|([0-9a-fA-F]{2}(?:\.)[0-9a-fA-F]{2}(?:\.)[0-9a-fA-F]{2}(?:\.)[0-9a-fA-F]{2}(?:\.)[0-9a-fA-F]{2}(?:\.)[0-9a-fA-F]{2})'

    if ($line -match $macRegex) {
        $macAddress = $matches[0]
        
        # Remove all separators (:, -, .) to get a clean MAC address string
        $cleanMac = $macAddress.Replace(":", "").Replace("-", "").Replace(".", "")

        # Get the first 6 characters (the OUI) for the lookup
        $macPrefix = $cleanMac.Substring(0, 6)
        
        # Look up the vendor in the hash table
        $vendorName = $vendorDB[$macPrefix]
        
        # If a vendor is found, append it to the line. Otherwise, add "Unknown".
        if ($null -ne $vendorName) {
            $outputLine = "$line`t`t$vendorName"
        } else {
            $outputLine = "$line`t`tUnknown"
        }

        # Add the result to an array of objects for easier CSV export
        $results += [PSCustomObject]@{
            "Original Line" = $line.Trim()
            "Vendor" = $vendorName
        }

        # Output the result to the console
        Write-Host $outputLine
    } else {
        # If no MAC address is found, just output the original line
        Write-Host $line
        $results += [PSCustomObject]@{
            "Original Line" = $line.Trim()
            "Vendor" = "N/A"
        }
    }
}

# Export the results to a new CSV file
# We'll reformat the output to have the original line and the vendor in separate columns for better CSV structure.
$results | Export-Csv -Path $outputFile -NoTypeInformation

# A simple confirmation message
Write-Host "`nProcessing complete. Results saved to $outputFile"
