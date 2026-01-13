Function Get-AccountLockoutStatus {
<#
.Synopsis
    Iterates through domain controllers to find lockout events (ID 4740).
#>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string[]]$ComputerName,

        [Parameter()]
        [string]$Username,

        [Parameter()]
        [int]$DaysFromToday = 3
    )

    BEGIN {
        # If no computers are specified, get all Domain Controllers
        if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
            try {
                $ComputerName = (Get-ADDomainController -Filter *).Name
            } catch {
                Write-Error "Could not retrieve Domain Controllers. Ensure ActiveDirectory module is loaded."
                return
            }
        }

        $StartTime = (Get-Date).AddDays(-$DaysFromToday)
        
        # Build the Filter Hashtable once
        $Filter = @{
            LogName   = 'Security'
            ID        = 4740
            StartTime = $StartTime
        }
        
        # Optimization: If username is provided, filter at the source
        if ($Username) { $Filter.Data = $Username }
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            try {
                $Events = Get-WinEvent -ComputerName $Computer -FilterHashtable $Filter -ErrorAction Stop
                
                foreach ($Event in $Events) {
                    # Create custom object and output immediately to the pipeline
                    [PSCustomObject]@{
                        Time           = $Event.TimeCreated
                        Username       = $Event.Properties[0].Value
                        CallerComputer = $Event.Properties[1].Value
                        DomainController = $Computer
                    }
                }
            } catch [System.Exception] {
                if ($_.Exception.Message -like "*No events were found*") {
                    Write-Verbose "No lockout events found on $Computer"
                } else {
                    Write-Warning "Failed to query $Computer : $($_.Exception.Message)"
                }
            }
        }
    }

    END {}
}
