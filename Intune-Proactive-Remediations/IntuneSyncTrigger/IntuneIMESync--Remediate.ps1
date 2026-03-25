<#
.SYNOPSIS
    Remediates Intune Management Extension activity by restarting the IME service and verifying log activity.

.DESCRIPTION
    This remediation script:
    1. Verifies that the Intune Management Extension service exists.
    2. Starts or restarts the service.
    3. Waits briefly for new IME activity.
    4. Verifies that the main IME log was updated.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System

.EXAMPLE
    .\IntuneIMESync--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 2.0
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'IntuneIMESync--Remediate.ps1'
$ScriptBaseName = 'IntuneIMESync--Remediate'
$SolutionName   = 'IntuneSyncTrigger'

# IME service and log settings
$ServiceName        = 'IntuneManagementExtension'
$ImeLogRoot         = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeMainLog         = Join-Path $ImeLogRoot 'IntuneManagementExtension.log'
$WaitAfterRestartSec = 30

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

# Check whether the current session has admin rights
function Test-IsAdministrator {
    try {
        $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

# Return the last write time of the IME log if it exists
function Get-ImeLogLastWriteTime {
    if (Test-Path -Path $ImeMainLog) {
        try {
            return (Get-Item -Path $ImeMainLog -ErrorAction Stop).LastWriteTime
        }
        catch {
            return $null
        }
    }

    return $null
}

# Return a readable time span string
function Get-AgeText {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$DateTimeValue
    )

    $Span = New-TimeSpan -Start $DateTimeValue -End (Get-Date)
    return ('{0} day(s), {1} hour(s), {2} minute(s), {3} second(s)' -f $Span.Days, $Span.Hours, $Span.Minutes, $Span.Seconds)
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Service name: $ServiceName"
Write-Log -Message "IME log path: $ImeMainLog"
Write-Log -Message "Wait after restart: $WaitAfterRestartSec second(s)"
Write-Log -Message "Log file: $LogFile"

try {
    # IME remediation should run elevated
    if (-not (Test-IsAdministrator)) {
        Write-Log -Message 'Administrative privileges are required.' -Level 'ERROR'
        exit 1
    }

    # Make sure the IME service exists
    $ImeService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $ImeService) {
        Write-Log -Message "IME service '$ServiceName' was not found." -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Current IME service state: $($ImeService.Status)"

    # Capture current log timestamp before service action
    $BeforeLogWriteTime = Get-ImeLogLastWriteTime
    if ($BeforeLogWriteTime) {
        Write-Log -Message "IME log last write time before action: $BeforeLogWriteTime"
        Write-Log -Message "IME log age before action: $(Get-AgeText -DateTimeValue $BeforeLogWriteTime)"
    }
    else {
        Write-Log -Message 'IME main log was not found before remediation.' -Level 'WARNING'
    }

    # Start or restart the IME service
    if ($ImeService.Status -eq 'Running') {
        Write-Log -Message 'Restarting Intune Management Extension service...'
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
        Write-Log -Message 'Intune Management Extension service restarted successfully.' -Level 'SUCCESS'
    }
    else {
        Write-Log -Message 'Starting Intune Management Extension service...'
        Start-Service -Name $ServiceName -ErrorAction Stop
        Write-Log -Message 'Intune Management Extension service started successfully.' -Level 'SUCCESS'
    }

    # Refresh service status
    $ImeService = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Log -Message "IME service state after action: $($ImeService.Status)"

    if ($ImeService.Status -ne 'Running') {
        Write-Log -Message 'IME service is not running after remediation.' -Level 'ERROR'
        exit 1
    }

    # Wait briefly for IME to produce new log activity
    Write-Log -Message "Waiting $WaitAfterRestartSec second(s) for IME activity..."
    Start-Sleep -Seconds $WaitAfterRestartSec

    # Verify the main log was updated
    $AfterLogWriteTime = Get-ImeLogLastWriteTime
    if (-not $AfterLogWriteTime) {
        Write-Log -Message 'IME main log was not found after remediation.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "IME log last write time after action: $AfterLogWriteTime"

    if ($BeforeLogWriteTime -and $AfterLogWriteTime -gt $BeforeLogWriteTime) {
        Write-Log -Message 'IME log was updated after service restart. IME activity was triggered successfully.' -Level 'SUCCESS'
        exit 0
    }

    if (-not $BeforeLogWriteTime) {
        Write-Log -Message 'IME log is now present after remediation. This is treated as successful activity.' -Level 'SUCCESS'
        exit 0
    }

    Write-Log -Message 'IME service changed successfully, but no newer IME log activity was detected.' -Level 'WARNING'
    exit 1
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------