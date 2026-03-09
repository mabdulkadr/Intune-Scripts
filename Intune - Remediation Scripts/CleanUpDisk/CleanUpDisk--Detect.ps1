<#
.SYNOPSIS
    Detects whether the Windows system drive has enough free space.

.DESCRIPTION
    This detection script checks the free space on the Windows system drive.
    If free space is less than or equal to the configured threshold,
    the device will be marked as non-compliant so remediation can run.

    Exit codes:
    0 = Compliant
    1 = Not compliant

.RUN AS
    System or User (depending on Intune assignment)

.EXAMPLE
    .\CleanUpDisk--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Minimum required free space (GB)
$StorageThresholdGB = 15

# Script metadata
$ScriptName   = 'CleanUpDisk--Detect.ps1'
$SolutionName = 'CleanUpDisk'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

# Build logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath 'CleanUpDisk--Detect.txt'

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if they don't exist
function Initialize-Logging {

    try {

        if (-not (Test-Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write message to console and log file
function Write-Log {

    param(
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
        try { Add-Content -Path $LogFile -Value $Line -Encoding UTF8 } catch {}
    }
}

# Convert bytes to readable size for logging
function Format-Size {

    param([Int64]$Bytes)

    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }

    return "$Bytes B"
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Initialize logging before detection
$LogReady = Initialize-Logging

Write-Log "Starting disk space detection for $ScriptName"

try {

    # Get system drive information
    $DriveLetter = $SystemDrive.TrimEnd(':').TrimEnd('\')
    $Drive       = Get-PSDrive -Name $DriveLetter -ErrorAction Stop

    $FreeBytes      = [Int64]$Drive.Free
    $ThresholdBytes = $StorageThresholdGB * 1GB

    Write-Log "Drive: $SystemDrive"
    Write-Log "Free space: $(Format-Size $FreeBytes)"
    Write-Log "Required space: $StorageThresholdGB GB"

    # Compare available space with threshold
    if ($FreeBytes -gt $ThresholdBytes) {

        Write-Log "Device is compliant. Enough free space available." 'SUCCESS'
        exit 0
    }
    else {

        Write-Log "Device is not compliant. Free space below threshold." 'WARNING'
        exit 1
    }

}
catch {

    Write-Log "Detection failed: $($_.Exception.Message)" 'ERROR'
    exit 1

}

#endregion ---------- Detection Logic ----------