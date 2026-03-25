<#
.SYNOPSIS
    Checks whether Microsoft Defender cloud-delivered protection is fully enabled.

.DESCRIPTION
    This detection script reads the current Microsoft Defender preferences and
    checks two values:

    - `MAPSReporting` must be set to `2`
    - `SubmitSamplesConsent` must be set to `3`

    If both values are already configured, the device is treated as compliant.
    If either value is different, the script returns non-compliant so the
    remediation script can apply the required settings.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-DefenderCloudProtectionStatus--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName           = 'Get-DefenderCloudProtectionStatus--Detect.ps1'
$SolutionName         = 'Get-DefenderCloudProtectionStatus'
$ScriptMode           = 'Detection'
$ExpectedMapsReporting = 2
$ExpectedSamplesConsent = 3
$Version              = 'C1'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-DefenderCloudProtectionStatus--Detect.txt'
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

Write-Log -Message 'Reading Microsoft Defender preferences.'

try {
    $preferences = Get-MpPreference -ErrorAction Stop
    Write-Log -Message ("Current MAPSReporting value: {0}" -f $preferences.MAPSReporting)
    Write-Log -Message ("Current SubmitSamplesConsent value: {0}" -f $preferences.SubmitSamplesConsent)

    if ($preferences.MAPSReporting -eq $ExpectedMapsReporting -and $preferences.SubmitSamplesConsent -eq $ExpectedSamplesConsent) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -OutputMessage "$Version COMPLIANT" -Message 'Defender cloud-delivered protection is fully enabled.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -OutputMessage "$Version NON-COMPLIANT" -Message 'One or more Defender cloud protection settings are not configured as expected.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -OutputMessage "$Version NON-COMPLIANT" -Message ("Failed to read Defender preferences: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
