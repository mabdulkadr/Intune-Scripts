<#
.SYNOPSIS
    Detects whether WinRM is enabled.

.DESCRIPTION
    This detection script uses Test-WSMan to verify whether WinRM is available
    on the local device.

    If WinRM responds successfully, the device is compliant.
    If the test fails, remediation should run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant

.RUN AS
    System

.EXAMPLE
    .\EnableWinRM--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'EnableWinRM--Detect.ps1'
$ScriptBaseName = 'EnableWinRM--Detect'
$SolutionName   = 'Enable WinRM'

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
Write-Log -Message "Log file: $LogFile"

try {
    # Test whether WinRM responds locally
    $Result = Test-WSMan -ErrorAction Stop

    if ($Result) {
        Write-Log -Message 'WinRM is enabled and responding.' -Level 'SUCCESS'
        exit 0
    }
    else {
        Write-Log -Message 'WinRM test did not return a valid result.' -Level 'WARNING'
        exit 1
    }
}
catch {
    Write-Log -Message "WinRM is disabled or unavailable: $($_.Exception.Message)" -Level 'WARNING'
    exit 1
}

#endregion ---------- Detection Logic ----------