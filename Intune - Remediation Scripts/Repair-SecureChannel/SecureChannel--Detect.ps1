<#
.SYNOPSIS
    Detects whether the device secure channel to the domain is healthy.

.DESCRIPTION
    This detection script verifies whether the device is domain-joined and whether
    the computer secure channel is working correctly.

    Exit codes:
    - Exit 0: Compliant or not applicable
    - Exit 1: Not compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\SecureChannel--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'SecureChannel--Detect.ps1'
$ScriptBaseName = 'SecureChannel--Detect'
$SolutionName   = 'Repair-SecureChannel'

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

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Log file: $LogFile"

try {
    # Get computer domain membership information
    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop

    # Skip devices that are not domain-joined
    if (-not $ComputerSystem.PartOfDomain) {
        Write-Log -Message 'Device is not domain-joined. Secure channel check is not applicable.' -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message "Domain: $($ComputerSystem.Domain)"
    Write-Log -Message 'Testing computer secure channel...'

    # Test the trust relationship with the domain
    $SecureChannelHealthy = Test-ComputerSecureChannel -ErrorAction Stop

    if ($SecureChannelHealthy) {
        Write-Log -Message 'Secure channel is healthy. Device is compliant.' -Level 'SUCCESS'
        exit 0
    }
    else {
        Write-Log -Message 'Secure channel is broken. Remediation is required.' -Level 'WARNING'
        exit 1
    }
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Detection Logic ----------