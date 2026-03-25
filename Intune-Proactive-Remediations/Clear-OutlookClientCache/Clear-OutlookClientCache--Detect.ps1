<#
.SYNOPSIS
    Detects whether Outlook cache cleanup should run.

.DESCRIPTION
    The script checks whether Outlook is installed in the expected Office path.

    Exit codes:
    - Exit 0: Outlook was not found
    - Exit 1: Outlook was found and remediation should run

.RUN AS
    System or User

.EXAMPLE
    .\Clear-OutlookClientCache--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Clear-OutlookClientCache--Detect.ps1'
$SolutionName = 'Clear-OutlookClientCache'
$ScriptMode   = 'Detection'
$OutlookPath  = 'C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Clear-OutlookClientCache--Detect.txt'

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

# Create the log folder and file when needed.
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

# Write the same banner to the console and the log file.
function Write-Banner {
    $lines = @(
        '',
        ('=' * 78),
        ("{0} | {1}" -f $SolutionName, $ScriptMode),
        ('=' * 78)
    )

    foreach ($line in $lines) {
        if ($line -eq ("{0} | {1}" -f $SolutionName, $ScriptMode)) {
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

# Write one formatted log line.
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

# Write the final message and exit with the right code.
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

Write-Log -Message ("Checking Outlook executable path: {0}" -f $OutlookPath)

if (Test-Path -Path $OutlookPath) {
    Finish-Script -ExitCode 1 -Level 'WARNING' -Message 'Outlook.exe was found. Remediation is required to clear the Outlook client cache.'
}

Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Outlook.exe was not found. Outlook client cache remediation is not required.'

#endregion ---------- Main ----------
