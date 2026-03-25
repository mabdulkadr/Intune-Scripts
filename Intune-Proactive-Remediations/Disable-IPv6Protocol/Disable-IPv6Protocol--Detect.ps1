<#
.SYNOPSIS
    Detects whether IPv6 remains enabled on any network adapter.

.DESCRIPTION
    This detection script queries the `ms_tcpip6` binding on every network
    adapter by using `Get-NetAdapterBinding`.

    It counts how many adapters still have the IPv6 binding enabled and how
    many already have it disabled. The script returns success only when every
    returned adapter binding for `ms_tcpip6` is disabled.

    Detection behavior:
    - Exit `0` when IPv6 is disabled on all detected adapters.
    - Exit `1` when IPv6 is still enabled on one or more adapters, when no
      bindings are returned, or when the query fails.

    Exit codes:
    - Exit 0: IPv6 is disabled on all detected adapters
    - Exit 1: IPv6 is still enabled, binding data could not be read, or detection failed

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Disable-IPv6Protocol--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName         = 'Disable-IPv6Protocol--Detect.ps1'
$SolutionName       = 'Disable-IPv6Protocol'
$ScriptMode         = 'Detection'
$BindingComponentId = 'ms_tcpip6'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Disable-IPv6Protocol--Detect.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

# Create the log folder and file when needed.
function Initialize-Log {
    try {
        if (-not (Test-Path -Path $LogRoot)) {
            New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }

        return $true
    }
    catch {
        Write-Host "Logging initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Write the same banner to the console and the log file.
function Write-Banner {
    $title = "{0} | {1}" -f $SolutionName, $ScriptMode
    $lines = @('', $BannerLine, $title, $BannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
        }
    }
}

# Write one formatted log line.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
        }
        catch {}
    }
}

# Write the final result, emit the Intune compliance state, and exit.
function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$ComplianceState
    )

    Write-Log -Message $Message -Level $Level

    if ($ComplianceState) {
        Write-Output $ComplianceState
    }

    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Querying adapter bindings for component: {0}" -f $BindingComponentId)

try {
    $allBindings = @(Get-NetAdapterBinding -ComponentID $BindingComponentId -ErrorAction Stop)

    if (-not $allBindings) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -ComplianceState 'Not Compliant' -Message ("No adapter bindings were returned for component '{0}'." -f $BindingComponentId)
    }

    $enabledBindings  = @($allBindings | Where-Object { $_.Enabled })
    $disabledBindings = @($allBindings | Where-Object { -not $_.Enabled })

    Write-Log -Message ("Total adapters checked: {0}" -f $allBindings.Count)
    Write-Log -Message ("Adapters with IPv6 enabled: {0}" -f $enabledBindings.Count)
    Write-Log -Message ("Adapters with IPv6 disabled: {0}" -f $disabledBindings.Count)

    if ($enabledBindings.Count -eq 0) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -ComplianceState 'Compliant' -Message 'IPv6 is disabled on all detected network adapters.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'IPv6 is still enabled on one or more network adapters.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -ComplianceState 'Not Compliant' -Message ("Failed to query IPv6 adapter bindings: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
