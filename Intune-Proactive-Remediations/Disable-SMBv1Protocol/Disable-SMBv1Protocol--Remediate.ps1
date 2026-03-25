<#
.SYNOPSIS
    Disables the SMBv1 server protocol.

.DESCRIPTION
    This remediation script disables SMBv1 by running
    `Set-SmbServerConfiguration -EnableSMB1Protocol 0`.

    Exit codes:
    - Exit 0: SMBv1 was disabled successfully
    - Exit 1: SMBv1 could not be disabled or verified

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Disable-SMBv1Protocol--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Disable-SMBv1Protocol--Remediate.ps1'
$SolutionName = 'Disable-SMBv1Protocol'
$ScriptMode   = 'Remediation'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Disable-SMBv1Protocol--Remediate.txt'
$BannerLine  = '=' * 78

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

Write-Log -Message 'Disabling SMBv1 server protocol.'

try {
    Set-SmbServerConfiguration -EnableSMB1Protocol 0 -Force -Confirm:$false -ErrorAction Stop | Out-Null
    $smbv1Enabled = (Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol

    if (-not $smbv1Enabled) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'SMBv1 was disabled successfully.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("SMBv1 remediation ran, but EnableSMB1Protocol is still {0}." -f $smbv1Enabled)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to disable SMBv1: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
