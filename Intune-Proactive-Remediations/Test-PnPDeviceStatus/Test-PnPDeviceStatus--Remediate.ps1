<#
.SYNOPSIS
    Removes present PnP devices that report an error state and triggers re-detection.

.DESCRIPTION
    This remediation script searches for present Plug and Play devices with
    `Status ERROR`, applies the same optional class and device ID filters used
    by the detection script, and then remediates each matching device with
    `pnputil.exe`.

    For every matched device, the script removes the current device instance by
    using `pnputil.exe /remove-device` and then asks Windows to scan for
    hardware changes again with `pnputil.exe /scan-devices`.

    Exit codes:
    - Exit 0: Remediation completed without a terminating error
    - Exit 1: Remediation failed or requires further action

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Test-PnPDeviceStatus--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Test-PnPDeviceStatus--Remediate.ps1'
$SolutionName = 'Test-PnPDeviceStatus'
$ScriptMode   = 'Remediation'

$ClassFilterExclude    = ''
$ClassFilterInclude    = '*'
$DeviceIDFilterExclude = ''
$DeviceIDFilterInclude = '*'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Test-PnPDeviceStatus--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    if (-not (Test-Path -Path $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}

function Write-Banner {
    Write-Host ''
    Write-Host $BannerLine -ForegroundColor DarkGray
    Write-Host ("{0} | {1}" -f $SolutionName, $ScriptMode) -ForegroundColor White
    Write-Host $BannerLine -ForegroundColor DarkGray
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0} | {1,-7} | {2}' -f $timestamp, $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    Write-Output $Message
    exit $ExitCode
}

function Test-WildcardMatch {
    param(
        [AllowNull()]
        [string]$Value,

        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Pattern) -or $Pattern -eq '*') {
        return $true
    }

    return ($Value -like $Pattern)
}

function Get-MatchingPnpDevices {
    $devices = Get-PnpDevice -PresentOnly -Status 'ERROR' -ErrorAction Stop

    return @(
        $devices | Where-Object {
            $deviceClass = [string]$_.Class
            $deviceId = [string]$_.InstanceId

            (Test-WildcardMatch -Value $deviceClass -Pattern $ClassFilterInclude) -and
            (-not $ClassFilterExclude -or $deviceClass -notlike $ClassFilterExclude) -and
            (Test-WildcardMatch -Value $deviceId -Pattern $DeviceIDFilterInclude) -and
            (-not $DeviceIDFilterExclude -or $deviceId -notlike $DeviceIDFilterExclude)
        }
    )
}

function Invoke-PnpUtil {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & pnputil.exe @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = @($output)
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message 'Starting PnP error-state remediation.'

    $matchedDevices = Get-MatchingPnpDevices
    $matchCount = @($matchedDevices).Count

    if ($matchCount -eq 0) {
        Finish-Script -Message 'No matching PnP devices in error state were found. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    $failureCount = 0

    foreach ($device in $matchedDevices) {
        $deviceName = if ($device.FriendlyName) { $device.FriendlyName } else { $device.InstanceId }
        Write-Log -Message ("Removing device: {0}" -f $deviceName)

        $removeResult = Invoke-PnpUtil -Arguments @('/remove-device', $device.InstanceId)
        if ($removeResult.ExitCode -ne 0) {
            $failureCount++
            Write-Log -Message ("Failed to remove device '{0}'. pnputil exit code: {1}" -f $deviceName, $removeResult.ExitCode) -Level 'ERROR'
            continue
        }

        Write-Log -Message ("Device removed successfully: {0}" -f $deviceName) -Level 'SUCCESS'

        $scanResult = Invoke-PnpUtil -Arguments @('/scan-devices')
        if ($scanResult.ExitCode -ne 0) {
            $failureCount++
            Write-Log -Message ("Hardware rescan failed after removing '{0}'. pnputil exit code: {1}" -f $deviceName, $scanResult.ExitCode) -Level 'ERROR'
            continue
        }

        Write-Log -Message ("Hardware rescan completed after removing '{0}'." -f $deviceName) -Level 'SUCCESS'
    }

    if ($failureCount -gt 0) {
        Finish-Script -Message ("Remediation completed with {0} failure(s)." -f $failureCount) -ExitCode 1 -Level 'WARNING'
    }

    Finish-Script -Message ("Remediation completed successfully for {0} matching device(s)." -f $matchCount) -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
