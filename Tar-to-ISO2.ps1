function New-IsoFile {
    <#
    .SYNOPSIS
        Creates a new .iso file using IMAPI2.
    #>
    [CmdletBinding(DefaultParameterSetName='Source')]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Source')]
        $Source,

        [Parameter(Position=1)]
        [string]$Path = "$env:temp\$((Get-Date).ToString('yyyyMMdd-HHmmss')).iso",

        [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
        [string]$BootFile,

        [ValidateSet('CDR','CDRW','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DISK','BDR','BDRE')]
        [string]$Media = 'DVDPLUSRW_DUALLAYER',

        [string]$Title = "ISO_IMAGE",

        [switch]$Force,

        [Parameter(ParameterSetName='Clipboard')]
        [switch]$FromClipboard
    )

    Begin {
        # Define Media Type mapping for IMAPI
        $MediaTypeNames = @('UNKNOWN','CDROM','CDR','CDRW','DVDROM','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','HDDVDROM','HDDVDR','HDDVDRAM','BDROM','BDR','BDRE')
        $MediaIndex = $MediaTypeNames.IndexOf($Media)

        # Initialize the FileSystemImage COM Object
        try {
            $Image = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
            $Image.VolumeName = $Title
            $Image.ChooseImageDefaultsForMediaType($MediaIndex)
        } catch {
            Write-Error "IMAPI2 is not available on this system."
            return
        }

        # Handling Bootable Options
        if ($BootFile) {
            Write-Verbose "Configuring bootable image using: $BootFile"
            $BootStream = New-Object -ComObject ADODB.Stream
            $BootStream.Type = 1 # adFileTypeBinary
            $BootStream.Open()
            $BootStream.LoadFromFile((Get-Item -LiteralPath $BootFile).FullName)
            
            $BootOptions = New-Object -ComObject IMAPI2FS.BootOptions
            $BootOptions.Manufacturer = "Microsoft"
            $BootOptions.PlatformId = 2 # EFI
            $BootOptions.AssignBootImage($BootStream)
            $Image.BootImageOptions = $BootOptions
        }
    }

    Process {
        if ($FromClipboard) {
            $Source = Get-Clipboard -Format FileDropList
        }

        foreach ($item in $Source) {
            $pathInfo = Get-Item -LiteralPath $item
            Write-Verbose "Adding: $($pathInfo.FullName)"
            try {
                # AddTree adds folders/files recursively
                $Image.Root.AddTree($pathInfo.FullName, $true)
            } catch {
                Write-Warning "Failed to add $($pathInfo.Name): $($_.Exception.Message)"
            }
        }
    }

    End {
        try {
            $ResultImage = $Image.CreateResultImage()
            $Stream = $ResultImage.ImageStream

            # Optimized Binary Write (Replaces the Unsafe C# block)
            $FileStream = [System.IO.File]::Create((New-Item -Path $Path -ItemType File -Force:$Force).FullName)
            
            # Use a 1MB buffer for high-speed writing
            $buffer = New-Object Byte[] 1048576 
            $ptr = [System.IntPtr]::Zero
            
            Write-Progress -Activity "Writing ISO" -Status $Path
            
            # Read from COM IStream and write to FileStream
            while ($true) {
                $read = 0
                $Stream.Read($buffer, $buffer.Length, [ref]$read)
                if ($read -eq 0) { break }
                $FileStream.Write($buffer, 0, $read)
            }

            $FileStream.Close()
            Write-Host "ISO created successfully at: $Path" -ForegroundColor Green
            Get-Item $Path
        }
        catch {
            Write-Error "Failed to finalize ISO: $($_.Exception.Message)"
        }
        finally {
            # Explicitly release COM objects to prevent memory leaks
            if ($Image) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Image) | Out-Null }
        }
    }
}
