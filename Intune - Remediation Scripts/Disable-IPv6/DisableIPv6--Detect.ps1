<#
.SYNOPSIS
    Detects whether IPv6 is disabled on all network adapters.

.DESCRIPTION
    This detection script checks the ms_tcpip6 binding on all network adapters.
    If IPv6 is disabled on every adapter, the device is compliant.
    If IPv6 is still enabled on one or more adapters, remediation should run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant

.RUN AS
    System or User (depending on Intune assignment)

.EXAMPLE
    .\DisableIPv6--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'DisableIPv6--Detect.ps1'
$ScriptBaseName = 'DisableIPv6--Detect'
$SolutionName   = 'Disable-IPv6'

# Network binding used to check IPv6 state
$BindingComponentId = 'ms_tcpip6'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write a message to console and log file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Binding component: $BindingComponentId"
Write-Log -Message "Log file: $LogFile"

try {
    # Get IPv6 binding status for all adapters
    $AllBindings = @(Get-NetAdapterBinding -ComponentID $BindingComponentId -ErrorAction Stop)

    if (-not $AllBindings) {
        Write-Log -Message "No adapter bindings were returned for component '$BindingComponentId'." -Level 'ERROR'
        exit 1
    }

    $DisabledBindings = @($AllBindings | Where-Object { $_.Enabled -eq $false })
    $EnabledBindings  = @($AllBindings | Where-Object { $_.Enabled -eq $true })

    Write-Log -Message "Total adapters checked: $($AllBindings.Count)"
    Write-Log -Message "Adapters with IPv6 disabled: $($DisabledBindings.Count)"
    Write-Log -Message "Adapters with IPv6 enabled: $($EnabledBindings.Count)"

    if ($EnabledBindings.Count -eq 0) {
        Write-Log -Message 'Compliant: IPv6 is disabled on all network adapters.' -Level 'SUCCESS'
        exit 0
    }
    else {
        Write-Log -Message 'Not compliant: IPv6 is still enabled on one or more network adapters.' -Level 'WARNING'

        foreach ($Binding in $EnabledBindings) {
            Write-Log -Message "IPv6 still enabled on adapter: $($Binding.Name)" -Level 'WARNING'
        }

        exit 1
    }
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Detection Logic ----------