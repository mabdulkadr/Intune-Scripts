<#
.SYNOPSIS
    Checks whether the Windows Search service exists or appears to be running.

.DESCRIPTION
    This detection script checks the `WSearch` service and preserves the
    original permissive detection behavior: the script considers Windows Search
    compliant when the internal counter is non-zero, which means the service
    merely existing is enough to satisfy the check.

    Exit codes:
    - Exit 0: The script considers Windows Search available or running
    - Exit 1: Windows Search was not found or not considered healthy

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Restart-WindowsSearch--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Restart-WindowsSearch--Detect.ps1'
$SolutionName = 'Restart-WindowsSearch'
$ScriptMode   = 'Detection'
$servicename  = 'WSearch'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Restart-WindowsSearch--Detect.txt'
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

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

$checkarray = 0
$serviceexist = Get-Service -Name $servicename -ErrorAction SilentlyContinue

if ($serviceexist) {
    $checkarray++
    Write-Log -Message ("Windows Search service exists: {0}" -f $servicename) -Level 'SUCCESS'

    if ($serviceexist.Status -eq 'Running') {
        $checkarray++
        Write-Log -Message 'Windows Search service is running.' -Level 'SUCCESS'
    }
    else {
        Write-Log -Message ("Windows Search service is not running. Current state: {0}" -f $serviceexist.Status) -Level 'WARNING'
    }
}
else {
    Write-Log -Message 'Windows Search service was not found.' -Level 'WARNING'
}

if ($checkarray -ne 0) {
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("The template considers Windows Search compliant. Counter value: {0}" -f $checkarray)
}

Finish-Script -ExitCode 1 -Level 'WARNING' -Message 'The template considers Windows Search non-compliant.'

#endregion ---------- Main ----------
