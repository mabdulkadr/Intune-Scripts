<#
.SYNOPSIS
    Restarts the Windows Update service.

.DESCRIPTION
    This remediation script checks whether the Windows Update service exists
    and restarts it when available.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Remediation failed or service was not found

.RUN AS
    System

.EXAMPLE
    .\RestartWindowsUpdateService--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'RestartWindowsUpdateService--Remediate.ps1'
$ScriptBaseName = 'RestartWindowsUpdateService--Remediate'
$SolutionName   = 'Restart-Windows-Update-Service'

# Target Windows Update service
$ServiceName = 'wuauserv'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
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
    $Line      = "[$TimeStamp] [$Level] $Message"

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

# Return service object when available
function Get-ServiceSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        Get-Service -Name $Name -ErrorAction Stop
    }
    catch {
        $null
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Service name: $ServiceName"
Write-Log -Message "Log file: $LogFile"

try {
    # Check whether the service exists
    $Service = Get-ServiceSafe -Name $ServiceName

    if (-not $Service) {
        Write-Log -Message "Service '$ServiceName' was not found." -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Service '$ServiceName' current status before restart: $($Service.Status)"

    # Start the service if it is stopped, otherwise restart it
    if ($Service.Status -eq 'Stopped') {
        Write-Log -Message "Service '$ServiceName' is stopped. Starting service..."
        Start-Service -Name $ServiceName -ErrorAction Stop
    }
    else {
        Write-Log -Message "Restarting service '$ServiceName'..."
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
    }

    # Refresh service state after action
    $Service = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Log -Message "Service '$ServiceName' current status after action: $($Service.Status)"

    if ($Service.Status -eq 'Running') {
        Write-Log -Message "Service '$ServiceName' is running successfully." -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message "Service '$ServiceName' action completed but the service is not running." -Level 'ERROR'
    exit 1
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------