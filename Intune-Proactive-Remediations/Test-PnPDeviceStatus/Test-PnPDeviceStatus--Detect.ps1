<#
.SYNOPSIS
    Detects present PnP devices that report an error state.

.DESCRIPTION
    This detection script queries Plug and Play devices with `Get-PnpDevice`
    and filters the results to devices that are currently present and report
    `Status ERROR`.

    Optional include and exclude filters can be applied to both device class
    and device ID. If one or more matching problem devices are found, the
    script outputs a summary and returns exit code `1` so remediation can
    remove and re-scan those devices.

    Exit codes:
    - Exit 0: No matching PnP devices with errors were found
    - Exit 1: One or more matching PnP devices with errors were found

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Test-PnPDeviceStatus--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Test-PnPDeviceStatus--Detect.ps1'
$SolutionName = 'Test-PnPDeviceStatus'
$ScriptMode   = 'Detection'

$ClassFilterExclude    = ''
$ClassFilterInclude    = '*'
$DeviceIDFilterExclude = ''
$DeviceIDFilterInclude = '*'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Test-PnPDeviceStatus--Detect.txt'
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

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message 'Starting PnP error-state detection.'

    $matchedDevices = Get-MatchingPnpDevices
    $matchCount = @($matchedDevices).Count

    if ($matchCount -eq 0) {
        Finish-Script -Message 'Compliant: No matching PnP devices in error state were found.' -ExitCode 0 -Level 'SUCCESS'
    }

    $summary = @(
        $matchedDevices |
        Select-Object -First 5 |
        ForEach-Object {
            if ($_.FriendlyName) { $_.FriendlyName } else { $_.InstanceId }
        }
    ) -join '; '

    if (-not $summary) {
        $summary = 'Matching devices detected.'
    }

    Finish-Script -Message ("Non-Compliant: Found {0} matching PnP device(s) in error state. {1}" -f $matchCount, $summary) -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
