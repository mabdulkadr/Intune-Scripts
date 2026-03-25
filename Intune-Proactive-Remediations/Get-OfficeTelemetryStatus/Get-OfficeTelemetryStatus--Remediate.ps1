<#
.SYNOPSIS
    Disables Office client telemetry for the current user.

.DESCRIPTION
    This remediation script creates the Office policy key under
    `HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry` and
    writes `DisableTelemetry = 1` as a DWORD value.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-OfficeTelemetryStatus--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName      = 'Get-OfficeTelemetryStatus--Remediate.ps1'
$SolutionName    = 'Get-OfficeTelemetryStatus'
$ScriptMode      = 'Remediation'
$ParentPath      = 'HKCU:\Software\Policies\Microsoft\office\common'
$KeyName         = 'clienttelemetry'
$RegistryPath    = 'HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry'
$ValueName       = 'DisableTelemetry'
$ValueType       = 'DWord'
$ExpectedValue   = 1

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-OfficeTelemetryStatus--Remediate.txt'
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

Write-Log -Message ("Ensuring registry path exists: {0}" -f $RegistryPath)

try {
    if (-not (Test-Path -Path $RegistryPath)) {
        New-Item -Path $ParentPath -Name $KeyName -Force | Out-Null
        Write-Log -Message 'Created Office telemetry policy key.'
    }

    New-ItemProperty -Path $RegistryPath -Name $ValueName -Value $ExpectedValue -PropertyType $ValueType -Force | Out-Null
    $currentValue = (Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop).$ValueName

    if ($currentValue -eq $ExpectedValue) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Office client telemetry policy was applied successfully for the current user.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Office telemetry policy did not match the expected value after remediation. Found {0}." -f $currentValue)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to configure Office telemetry policy: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
