<#
.SYNOPSIS
    Picks a specified number of random lines from an input text file and saves them to an output file.

.DESCRIPTION
    This script reads all lines from an input text file, randomly selects a specified quantity of those lines,
    and then writes the selected lines to a new output text file.

.PARAMETER InputFile
    The path to the input text file from which to pick random lines.

.PARAMETER OutputFile
    The path to the output text file where the selected random lines will be saved.

.PARAMETER LinesToPick
    (Optional) The number of random lines to pick. Defaults to 100.

.EXAMPLE
    # Pick 100 random lines from rockyou.txt and save to 100_rockyou.txt
    .\Pick-RandomLines.ps1 -InputFile "rockyou.txt" -OutputFile "100_rockyou.txt"

.EXAMPLE
    # Pick 50 random lines from log.txt and save to C:\temp\random_log.txt
    .\Pick-RandomLines.ps1 -InputFile "log.txt" -OutputFile "C:\temp\random_log.txt" -LinesToPick 50

.NOTES
    This script reads the entire input file into memory, which might be an issue for extremely large files
    (e.g., many gigabytes). For typical use cases, it should be fine.
    If the number of lines to pick is greater than the total lines in the input file, all lines will be selected.
#>
param (
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$true)]
    [string]$OutputFile,

    [int]$LinesToPick = 100
)

# Check if input file exists
if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
    Write-Error "Error: Input file '$InputFile' not found."
    exit 1
}

Write-Host "Reading lines from '$InputFile'..."

try {
    # Read all lines from the input file into an array
    # -Raw ensures the entire file content is treated as a single string,
    # then .Split([Environment]::NewLine) breaks it into lines.
    # We use .Split() on the raw content to ensure consistent line endings and
    # to avoid potential empty lines at the end that Get-Content without -Raw might produce.
    $AllLines = (Get-Content -Path $InputFile -Raw).Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

    # If the file is empty or only contains empty lines after splitting
    if ($AllLines.Count -eq 0) {
        Write-Warning "Input file '$InputFile' is empty or contains only blank lines. No lines to pick."
        # Create an empty output file
        Set-Content -Path $OutputFile -Value ""
        exit 0
    }

    Write-Host "Input file contains $($AllLines.Count) lines."

    # Determine the actual number of lines to pick
    # If LinesToPick is more than available lines, just take all available lines
    $ActualLinesToPick = [System.Math]::Min($LinesToPick, $AllLines.Count)

    Write-Host "Picking $ActualLinesToPick random lines..."

    # Pick random lines
    # Get-Random -Count $ActualLinesToPick selects unique random elements from the collection
    $RandomLines = $AllLines | Get-Random -Count $ActualLinesToPick

    # Save the picked lines to the output file
    $RandomLines | Set-Content -Path $OutputFile -Force

    Write-Host "Successfully selected $ActualLinesToPick random lines from '$InputFile' into '$OutputFile'."
}
catch {
    Write-Error "An error occurred during processing: $($_.Exception.Message)"
    exit 1
}
