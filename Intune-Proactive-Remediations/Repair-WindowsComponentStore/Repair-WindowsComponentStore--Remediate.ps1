<#
.SYNOPSIS
    Repairs Windows component store and system file integrity issues.

.DESCRIPTION
    This remediation script runs `DISM /RestoreHealth` followed by
    `SFC /scannow`, then checks whether a reboot is required to finalize the
    repair. It is intended for use with Intune Remediations.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Remediation failed
    - Exit 3010: Reboot required to finalize repairs

.RUN AS
    System

.EXAMPLE
    .\Repair-WindowsComponentStore--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Repair-WindowsComponentStore--Remediate.ps1'
$SolutionName = 'Repair-WindowsComponentStore'
$ScriptMode   = 'Remediation'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-WindowsComponentStore--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

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

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName               = $FilePath
    $startInfo.Arguments              = $Arguments
    $startInfo.UseShellExecute        = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError  = $true
    $startInfo.CreateNoWindow         = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    [void]$process.Start()
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError  = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut   = $standardOutput
        StdErr   = $standardError
    }
}

function Test-RebootPending {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        return $true
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        return $true
    }

    try {
        $pendingRename = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        return [bool]($pendingRename -and $pendingRename.PendingFileRenameOperations)
    }
    catch {
        return $false
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    $rebootPendingBefore = Test-RebootPending
    Write-Log -Message ("Reboot pending before repair: {0}" -f $rebootPendingBefore)
    if ($rebootPendingBefore) {
        Write-Log -Message 'A reboot is already pending before repair starts.' -Level 'WARNING'
    }

    Write-Log -Message 'Running DISM RestoreHealth.'
    $dismResult = Invoke-ExternalCommand -FilePath 'dism.exe' -Arguments '/Online /Cleanup-Image /RestoreHealth'
    Write-Log -Message ("DISM RestoreHealth exit code: {0}" -f $dismResult.ExitCode)

    if ($dismResult.ExitCode -ne 0) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'DISM RestoreHealth failed.'
    }

    Write-Log -Message 'DISM RestoreHealth completed successfully.' -Level 'SUCCESS'

    Write-Log -Message 'Running SFC Scannow.'
    $sfcResult = Invoke-ExternalCommand -FilePath 'sfc.exe' -Arguments '/scannow'
    Write-Log -Message ("SFC exit code: {0}" -f $sfcResult.ExitCode)

    $sfcOutput = '{0} {1}' -f $sfcResult.StdOut, $sfcResult.StdErr
    if ($sfcOutput -match 'did not find any integrity violations') {
        Write-Log -Message 'SFC found no integrity violations.' -Level 'SUCCESS'
    }
    elseif ($sfcOutput -match 'successfully repaired') {
        Write-Log -Message 'SFC repaired integrity violations successfully.' -Level 'SUCCESS'
    }
    elseif ($sfcOutput -match 'unable to fix some') {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'SFC could not repair some files. Review CBS.log.'
    }
    else {
        Write-Log -Message 'SFC completed with an unrecognized result. Review the output if needed.' -Level 'WARNING'
    }

    $rebootPendingAfter = Test-RebootPending
    Write-Log -Message ("Reboot pending after repair: {0}" -f $rebootPendingAfter)

    if ($rebootPendingBefore -or $rebootPendingAfter) {
        Finish-Script -ExitCode 3010 -Level 'WARNING' -Message 'Repairs completed, but a reboot is required.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Windows component store remediation completed successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
