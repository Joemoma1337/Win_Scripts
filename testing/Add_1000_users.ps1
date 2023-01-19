# Define the arrays of possible first and last names
$firstNames = @("Ashley","Barbara","Charles","David","Elizabeth","Felix","George","Helen","Isabella","James","Karen","Larry","Mary","Nicole","Olivia","Patricia","Qino","Robert","Stephen","Thomas","Ulysses","Vincent","William","Xavier","Yosef","Zoey")
$lastNames = @("Anderson","Brown","Clark","Dixon","Easmon","Flores","Garcia","Hernandez","Lee","Johnson","King","Lopez","Miller","Nguyen","Ortiz","Perez","Qin","Rodriguez","Smith ","Thomas","Ulrich","Vaughn","Williams","Xenos","Young","Zager")

$combinedNames = @()

do {
    # Generate a random index for the first and last name arrays
    $randomFirstNameIndex = Get-Random -Minimum 0 -Maximum ($firstNames.Count-1)
    $randomLastNameIndex = Get-Random -Minimum 0 -Maximum ($lastNames.Count-1)

    # Get the random first and last name using the generated indices
    $randomFirstName = $firstNames[$randomFirstNameIndex]
    $randomLastName = $lastNames[$randomLastNameIndex]

    # Combine the first and last name
    $combinedName = "$randomFirstName $randomLastName"

    # Get the first letter of the first name
    $firstLetter = $randomFirstName.Substring(0,1)
    # Create the SAM name by concatenating the first letter of the first name with the last name
    $SAM = $firstLetter + $randomLastName

    # Check if the combined name has already been generated
} while ($combinedNames -contains $combinedName)

$combinedNames += $combinedName

# Print the random first and last name on the same line
Write-Output "Random Name: $combinedName"
Write-Output "SAM Name: $SAM"
