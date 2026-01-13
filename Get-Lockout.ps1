Function Get-AccountLockoutStatus {
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
        # If no ComputerName is provided, get all DCs dynamically
        if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
            $ComputerName = (Get-ADDomainController -Filter *).Name
        }

        # Pre-calculate start time
        $StartTime = (Get-Date).AddDays(-$DaysFromToday)

        # Build the filter hashtable once
        $Filter = @{
            LogName   = 'Security'
            ID        = 4740
            StartTime = $StartTime
        }
        
        # Optimization: Filter by Username at the SOURCE if provided
        if ($Username) { $Filter.Data = $Username }
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            try {
                # Query the DC
                $Events = Get-WinEvent -ComputerName $Computer -FilterHashtable $Filter -ErrorAction Stop
                
                foreach ($Event in $Events) {
                    # Stream objects directly to the pipeline instead of building an array
                    [PSCustomObject]@{
                        Time             = $Event.TimeCreated
                        Username         = $Event.Properties[0].Value
                        CallerComputer   = $Event.Properties[1].Value
                        DomainController = $Computer
                    }
                }
            }
            catch [System.Exception] {
                if ($_.Exception.Message -like "*No events were found*") {
                    Write-Verbose "No lockouts found on $Computer for the specified criteria."
                } else {
                    Write-Warning "Could not query $Computer : $($_.Exception.Message)"
                }
            }
        }
    }
}
