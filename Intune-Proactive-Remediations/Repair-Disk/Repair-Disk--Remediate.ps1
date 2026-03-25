<#
.SYNOPSIS
    Scans the system drive and reports whether file system issues were found.

.DESCRIPTION
    This detection-only script resolves the system drive, runs
    `Repair-Volume -Scan`, and compares the returned scan text to the expected
    healthy token used by the original script logic.

    Exit codes:
    - Exit 0: Scan output matched the expected healthy value
    - Exit 1: Scan output indicated issues or the check failed

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Repair-Disk--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName          = 'Repair-Disk--Remediate'
$SolutionName        = 'Repair-Disk'
$ScriptMode          = 'Remediation'
$ExpectedHealthyText = 'NoErrorsFound'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-DiskFileSystem--Detect.txt'
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

function Get-SystemDriveLetter {
    return $SystemDrive.TrimEnd('\').TrimEnd(':')
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    $driveLetter = Get-SystemDriveLetter
    Write-Log -Message ("Scanning file system on drive {0}: with Repair-Volume -Scan." -f $driveLetter)

    $scanMessages = @(
        & {
            Repair-Volume -DriveLetter $driveLetter -Scan -Verbose -ErrorAction Stop 4>&1
        } | ForEach-Object {
            if ($_ -is [System.Management.Automation.VerboseRecord]) {
                $_.Message
            }
            elseif ($_.PSObject.Properties['HealthStatus']) {
                [string]$_.HealthStatus
            }
            else {
                [string]$_
            }
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    $scanResult = ($scanMessages -join ' | ').Trim()

    if ([string]::IsNullOrWhiteSpace($scanResult)) {
        $scanResult = 'No scan output was returned.'
    }

    Write-Output $scanResult
    Write-Log -Message ("Scan result: {0}" -f $scanResult)

    if ($scanResult -match [regex]::Escape($ExpectedHealthyText)) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Compliant. Scan output matched the expected healthy value: {0}" -f $ExpectedHealthyText)
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Non-compliant. Scan output did not match the expected healthy value: {0}" -f $ExpectedHealthyText)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Repair-Volume scan failed: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
