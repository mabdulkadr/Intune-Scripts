<#
.SYNOPSIS
    Detects whether Windows system health repair is required.

.DESCRIPTION
    This detection script checks for a pending reboot state and runs
    `DISM /CheckHealth` to identify whether component store issues may require
    remediation. It is intended for use with Intune Remediations.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\Repair-WindowsComponentStore--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Repair-WindowsComponentStore--Detect.ps1'
$SolutionName = 'Repair-WindowsComponentStore'
$ScriptMode   = 'Detection'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-WindowsComponentStore--Detect.txt'
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
    $needsRemediation = $false

    $rebootPending = Test-RebootPending
    Write-Log -Message ("Reboot pending: {0}" -f $rebootPending)
    if ($rebootPending) {
        $needsRemediation = $true
        Write-Log -Message 'A pending reboot was detected.' -Level 'WARNING'
    }

    Write-Log -Message 'Running DISM CheckHealth.'
    $dismResult = Invoke-ExternalCommand -FilePath 'dism.exe' -Arguments '/Online /Cleanup-Image /CheckHealth'
    Write-Log -Message ("DISM CheckHealth exit code: {0}" -f $dismResult.ExitCode)

    if ($dismResult.ExitCode -ne 0) {
        $needsRemediation = $true
        Write-Log -Message 'DISM CheckHealth returned a non-zero exit code.' -Level 'WARNING'
    }

    $combinedOutput = '{0} {1}' -f $dismResult.StdOut, $dismResult.StdErr
    if ($combinedOutput -match 'repairable|corruption detected|component store corruption') {
        $needsRemediation = $true
        Write-Log -Message 'DISM output indicates repairable corruption.' -Level 'WARNING'
    }

    if ($needsRemediation) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message 'Windows component store remediation is required.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Windows component store health is compliant.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
