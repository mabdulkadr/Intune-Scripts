<#
.SYNOPSIS
    Detects whether the Windows Update service is installed and running.

.DESCRIPTION
    This detection script checks whether the Windows Update service exists
    and verifies that its current status is Running.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\RestartWindowsUpdateService--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'RestartWindowsUpdateService--Detect.ps1'
$ScriptBaseName = 'RestartWindowsUpdateService--Detect'
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


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Service name: $ServiceName"
Write-Log -Message "Log file: $LogFile"

try {
    # Check whether the service exists
    $Service = Get-ServiceSafe -Name $ServiceName

    if (-not $Service) {
        Write-Log -Message "Service '$ServiceName' was not found." -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Service '$ServiceName' current status: $($Service.Status)"

    # Device is compliant only when the service is running
    if ($Service.Status -eq 'Running') {
        Write-Log -Message "Service '$ServiceName' is installed and running. Device is compliant." -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message "Service '$ServiceName' exists but is not running. Remediation is required." -Level 'WARNING'
    exit 1
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Detection Logic ----------