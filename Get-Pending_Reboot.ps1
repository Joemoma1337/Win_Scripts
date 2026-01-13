Function Get-PendingReboot {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("CN", "Computer")]
        [String[]]$ComputerName = "$env:COMPUTERNAME",
        
        [Parameter()]
        [Int]$ThrottleLimit = 32
    )

    Process {
        # Using CIM Sessions allows for parallel processing and better timeout handling
        $SessionOptions = New-CimSessionOption -Protocol Dcom # Fallback to Dcom if WinRM is off
        $Sessions = New-CimSession -ComputerName $ComputerName -Option $SessionOptions -ErrorAction SilentlyContinue

        foreach ($Session in $Sessions) {
            try {
                $Computer = $Session.ComputerName
                
                # 1. Component Based Servicing (CBS)
                $CBSPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
                $CBS = (Get-CimInstance -Namespace root\default -ClassName StdRegProv -CimSession $Session -ErrorAction SilentlyContinue | 
                        Invoke-CimMethod -MethodName EnumKey -Arguments @{hDefKey=[uint32]2147483650; sSubKeyName=$CBSPath}).ReturnValue -eq 0

                # 2. Windows Update
                $WUPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
                $WUAU = (Get-CimInstance -Namespace root\default -ClassName StdRegProv -CimSession $Session -ErrorAction SilentlyContinue | 
                         Invoke-CimMethod -MethodName EnumKey -Arguments @{hDefKey=[uint32]2147483650; sSubKeyName=$WUPath}).ReturnValue -eq 0

                # 3. Pending File Rename Operations
                $SMPath = "SYSTEM\CurrentControlSet\Control\Session Manager"
                $PFRO = (Get-CimInstance -Namespace root\default -ClassName StdRegProv -CimSession $Session | 
                         Invoke-CimMethod -MethodName GetMultiStringValue -Arguments @{hDefKey=[uint32]2147483650; sSubKeyName=$SMPath; sValueName="PendingFileRenameOperations"}).sValue

                # 4. Computer Rename / Domain Join
                $ActComp = (Get-CimInstance -Namespace root\default -ClassName StdRegProv -CimSession $Session | 
                            Invoke-CimMethod -MethodName GetStringValue -Arguments @{hDefKey=[uint32]2147483650; sSubKeyName="SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName"; sValueName="ComputerName"}).sValue
                $Comp = (Get-CimInstance -Namespace root\default -ClassName StdRegProv -CimSession $Session | 
                         Invoke-CimMethod -MethodName GetStringValue -Arguments @{hDefKey=[uint32]2147483650; sSubKeyName="SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName"; sValueName="ComputerName"}).sValue
                
                $PendRename = $ActComp -ne $Comp

                # 5. SCCM Client SDK
                $SCCM = $false
                try {
                    $SCCM_Result = Invoke-CimMethod -Namespace root\ccm\ClientSDK -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending -CimSession $Session -ErrorAction SilentlyContinue
                    if ($SCCM_Result.IsHardRebootPending -or $SCCM_Result.RebootPending) { $SCCM = $true }
                } catch { $SCCM = $null }

                # Construct Output
                [PSCustomObject]@{
                    Computer           = $Computer
                    CBServicing        = $CBS
                    WindowsUpdate      = $WUAU
                    CCMClientSDK       = $SCCM
                    PendComputerRename = $PendRename
                    PendFileRename     = [bool]$PFRO
                    RebootPending      = ($CBS -or $WUAU -or $PendRename -or $PFRO -or $SCCM)
                }
            } catch {
                Write-Warning "Failed to query $Computer : $($_.Exception.Message)"
            }
        }
        
        # Cleanup Sessions
        $Sessions | Remove-CimSession
    }
}
