<#
.SYNOPSIS
    Checks whether automatic time zone detection is enabled.

.DESCRIPTION
    This detection script reads the two registry values that Windows depends on
    for automatic time zone updates.

    It checks whether location access is allowed and whether the
    `tzautoupdate` service is configured with the expected startup value. If
    either setting is wrong, the device is marked as non-compliant.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Set-AutomaticTimeZone--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName           = 'Set-AutomaticTimeZone--Detect.ps1'
$SolutionName         = 'Set-AutomaticTimeZone'
$ScriptMode           = 'Detection'
$LocationConsentPath  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
$LocationConsentName  = 'Value'
$LocationConsentValue = 'Allow'
$TimeZoneServicePath  = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$TimeZoneServiceName  = 'Start'
$TimeZoneServiceValue = 3

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Set-AutomaticTimeZone--Detect.txt'
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

function Get-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name)
    }
    catch {
        return $null
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
    $locationValue = Get-RegistryValue -Path $LocationConsentPath -Name $LocationConsentName
    $timeZoneValue = Get-RegistryValue -Path $TimeZoneServicePath -Name $TimeZoneServiceName

    Write-Log -Message ("Location consent current value: {0}" -f $(if ($null -ne $locationValue) { $locationValue } else { '<missing>' }))
    Write-Log -Message ("tzautoupdate Start current value: {0}" -f $(if ($null -ne $timeZoneValue) { $timeZoneValue } else { '<missing>' }))

    if ($locationValue -ne $LocationConsentValue) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Location consent is not configured as expected. Expected: {0}" -f $LocationConsentValue)
    }

    if ([int]$timeZoneValue -ne $TimeZoneServiceValue) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("tzautoupdate Start is not configured as expected. Expected: {0}" -f $TimeZoneServiceValue)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Automatic time zone settings are configured correctly.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
