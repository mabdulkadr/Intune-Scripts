<#
.SYNOPSIS
    Detects whether the device secure channel to the domain is healthy.

.DESCRIPTION
    This detection script verifies whether the device is domain-joined and whether
    the computer secure channel is working correctly. It is intended for use with
    Intune Remediations.

    Exit codes:
    - Exit 0: Compliant or not applicable
    - Exit 1: Not compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\Repair-ADSecureChannel--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Repair-ADSecureChannel--Detect.ps1'
$SolutionName = 'Repair-ADSecureChannel'
$ScriptMode   = 'Detection'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-ADSecureChannel--Detect.txt'
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
        try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
    }
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$OutputMessage
    )

    Write-Log -Message $Message -Level $Level

    if ($OutputMessage) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop

    if (-not $computerSystem.PartOfDomain) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Device is not domain-joined. Secure channel check is not applicable.'
    }

    Write-Log -Message ("Domain: {0}" -f $computerSystem.Domain)
    Write-Log -Message 'Device is domain-joined. Testing the computer secure channel.'

    $secureChannelHealthy = Test-ComputerSecureChannel -ErrorAction Stop

    if ($secureChannelHealthy) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Secure channel is healthy. System is compliant.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message 'Secure channel is broken. Remediation is required.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
