<#
.SYNOPSIS
    Disables IPv6 adapter bindings and writes the system-wide IPv6 registry setting.

.DESCRIPTION
    This remediation script uses `Get-NetAdapterBinding` to find adapters where
    the `ms_tcpip6` binding is still enabled, then disables that binding with
    `Disable-NetAdapterBinding`.

    After the adapter-level changes, the script writes
    `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\DisabledComponents`
    as a `DWORD` with the value `255` to disable IPv6 components at the system
    level.

    The script returns success only when the registry update succeeds and no
    adapter-level disable operations fail. A restart is required before all
    changes fully take effect.

    Exit codes:
    - Exit 0: IPv6 bindings were handled successfully and the registry value was written
    - Exit 1: One or more adapter changes failed, the registry update failed, or remediation could not complete

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Disable-IPv6Protocol--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName        = 'Disable-IPv6Protocol--Remediate.ps1'
$SolutionName      = 'Disable-IPv6Protocol'
$ScriptMode        = 'Remediation'
$BindingComponentId = 'ms_tcpip6'
$RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
$RegistryName      = 'DisabledComponents'
$DesiredValue      = 255

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Disable-IPv6Protocol--Remediate.txt'
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

# Write the final message and exit with the right code.
function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
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
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("No adapter bindings were returned for component '{0}'." -f $BindingComponentId)
    }

    $enabledBindings = @($allBindings | Where-Object { $_.Enabled })
    Write-Log -Message ("Total adapters checked: {0}" -f $allBindings.Count)
    Write-Log -Message ("Adapters with IPv6 enabled: {0}" -f $enabledBindings.Count)

    $bindingErrors = 0

    foreach ($binding in $enabledBindings) {
        try {
            Disable-NetAdapterBinding -Name $binding.Name -ComponentID $BindingComponentId -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Log -Message ("IPv6 was disabled on adapter: {0}" -f $binding.Name) -Level 'SUCCESS'
        }
        catch {
            $bindingErrors++
            Write-Log -Message ("Failed to disable IPv6 on adapter '{0}': {1}" -f $binding.Name, $_.Exception.Message) -Level 'WARNING'
        }
    }

    Write-Log -Message ("Writing registry value {0}\\{1}={2}" -f $RegistryPath, $RegistryName, $DesiredValue)
    New-ItemProperty -Path $RegistryPath -Name $RegistryName -PropertyType DWord -Value $DesiredValue -Force -ErrorAction Stop | Out-Null

    $currentValue = Get-ItemPropertyValue -Path $RegistryPath -Name $RegistryName -ErrorAction Stop
    if ($currentValue -ne $DesiredValue) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Registry verification failed. Expected {0}, found {1}." -f $DesiredValue, $currentValue)
    }

    if ($bindingErrors -gt 0) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("IPv6 registry setting was applied, but adapter-level disable failed on {0} adapter(s)." -f $bindingErrors)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'IPv6 was disabled successfully. A restart is required for the full system effect.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to disable IPv6: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
