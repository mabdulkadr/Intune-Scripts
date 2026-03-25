<#
.SYNOPSIS
    Detects whether Windows system health repair is required.

.DESCRIPTION
    This detection script checks for a pending reboot state and runs
    DISM /CheckHealth to identify whether component store issues may require
    remediation.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\WindowsSystemHealth--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'WindowsSystemHealth--Detect.ps1'
$ScriptBaseName = 'WindowsSystemHealth--Detect'
$SolutionName   = 'Windows-SystemHealth-Repair'

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

# Run an external command and capture output
function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments
    )

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName               = $FilePath
    $StartInfo.Arguments              = $Arguments
    $StartInfo.UseShellExecute        = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError  = $true
    $StartInfo.CreateNoWindow         = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    [void]$Process.Start()

    $StandardOutput = $Process.StandardOutput.ReadToEnd()
    $StandardError  = $Process.StandardError.ReadToEnd()

    $Process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $Process.ExitCode
        StdOut   = $StandardOutput
        StdErr   = $StandardError
    }
}

# Check common reboot pending indicators
function Test-RebootPending {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        return $true
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        return $true
    }

    try {
        $PendingRename = Get-ItemProperty `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name 'PendingFileRenameOperations' `
            -ErrorAction SilentlyContinue

        if ($PendingRename -and $PendingRename.PendingFileRenameOperations) {
            return $true
        }
    }
    catch {}

    return $false
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Computer name: $env:COMPUTERNAME"
Write-Log -Message "Log file: $LogFile"

try {
    $NeedsRemediation = $false

    # Check whether a reboot is pending
    $RebootPending = Test-RebootPending
    Write-Log -Message "Reboot pending: $RebootPending"

    if ($RebootPending) {
        Write-Log -Message 'A pending reboot was detected.' -Level 'WARNING'
        $NeedsRemediation = $true
    }

    # Run a lightweight DISM health check
    Write-Log -Message 'Running DISM CheckHealth...'
    $DismResult = Invoke-ExternalCommand -FilePath 'dism.exe' -Arguments '/Online /Cleanup-Image /CheckHealth'

    Write-Log -Message "DISM CheckHealth exit code: $($DismResult.ExitCode)"

    if ($DismResult.ExitCode -ne 0) {
        Write-Log -Message 'DISM CheckHealth returned a non-zero exit code.' -Level 'WARNING'
        $NeedsRemediation = $true
    }

    # Check DISM output for common corruption indicators
    if ($DismResult.StdOut -match 'repairable|corruption detected|component store corruption') {
        Write-Log -Message 'DISM output indicates repairable corruption.' -Level 'WARNING'
        $NeedsRemediation = $true
    }

    if ($DismResult.StdErr) {
        Write-Log -Message "DISM standard error output: $($DismResult.StdErr.Trim())"
    }

    if ($NeedsRemediation) {
        Write-Log -Message 'System health remediation is required.' -Level 'WARNING'
        exit 1
    }

    Write-Log -Message 'System health is compliant. No remediation is required.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Detection Logic ----------