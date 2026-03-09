<#
.SYNOPSIS
    Repairs Windows component store and system file integrity issues.

.DESCRIPTION
    This remediation script runs DISM /RestoreHealth followed by SFC /scannow,
    then checks whether a reboot is required to finalize the repair.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Remediation failed
    - Exit 3010: Reboot required to finalize repairs

.RUN AS
    System

.EXAMPLE
    .\WindowsSystemHealth--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'WindowsSystemHealth--Remediate.ps1'
$ScriptBaseName = 'WindowsSystemHealth--Remediate'
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

# Evaluate SFC output and return a simple result
function Get-SfcResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputText
    )

    if ($OutputText -match 'did not find any integrity violations') {
        return 'NoIssues'
    }

    if ($OutputText -match 'successfully repaired') {
        return 'Repaired'
    }

    if ($OutputText -match 'unable to fix some') {
        return 'Unrepaired'
    }

    return 'Unknown'
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Computer name: $env:COMPUTERNAME"
Write-Log -Message "Log file: $LogFile"

try {
    # Check reboot state before repair starts
    $RebootPendingBefore = Test-RebootPending
    Write-Log -Message "Reboot pending before repair: $RebootPendingBefore"

    if ($RebootPendingBefore) {
        Write-Log -Message 'A reboot is already pending before repair starts.' -Level 'WARNING'
    }

    # Repair the component store first
    Write-Log -Message 'Running DISM RestoreHealth...'
    $DismResult = Invoke-ExternalCommand -FilePath 'dism.exe' -Arguments '/Online /Cleanup-Image /RestoreHealth'

    Write-Log -Message "DISM RestoreHealth exit code: $($DismResult.ExitCode)"

    if ($DismResult.StdErr) {
        Write-Log -Message "DISM standard error output: $($DismResult.StdErr.Trim())"
    }

    if ($DismResult.ExitCode -ne 0) {
        Write-Log -Message 'DISM RestoreHealth failed. Remediation stopped.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message 'DISM RestoreHealth completed successfully.' -Level 'SUCCESS'

    # Run SFC after DISM
    Write-Log -Message 'Running SFC Scannow...'
    $SfcResult = Invoke-ExternalCommand -FilePath 'sfc.exe' -Arguments '/scannow'

    Write-Log -Message "SFC exit code: $($SfcResult.ExitCode)"

    if ($SfcResult.StdErr) {
        Write-Log -Message "SFC standard error output: $($SfcResult.StdErr.Trim())"
    }

    $SfcStatus = Get-SfcResult -OutputText $SfcResult.StdOut

    switch ($SfcStatus) {
        'NoIssues' {
            Write-Log -Message 'SFC found no integrity violations.' -Level 'SUCCESS'
        }
        'Repaired' {
            Write-Log -Message 'SFC repaired integrity violations successfully.' -Level 'SUCCESS'
        }
        'Unrepaired' {
            Write-Log -Message 'SFC could not repair some files. Review CBS.log.' -Level 'ERROR'
            exit 1
        }
        default {
            Write-Log -Message 'SFC completed with an unrecognized result. Review CBS.log if needed.' -Level 'WARNING'
        }
    }

    # Check reboot state again after repair
    $RebootPendingAfter = Test-RebootPending
    Write-Log -Message "Reboot pending after repair: $RebootPendingAfter"

    if ($RebootPendingBefore -or $RebootPendingAfter) {
        Write-Log -Message 'A reboot is required to finalize repairs.' -Level 'WARNING'
        exit 3010
    }

    Write-Log -Message 'Windows system health remediation completed successfully.' -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Remediation failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------