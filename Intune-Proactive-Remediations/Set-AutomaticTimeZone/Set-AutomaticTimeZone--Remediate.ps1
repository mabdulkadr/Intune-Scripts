<#
.SYNOPSIS
    Enables the Windows settings required for automatic time zone updates.

.DESCRIPTION
    This remediation script writes the two registry values needed for automatic
    time zone detection to work properly.

    It allows location access in the Capability Access Manager key and sets the
    `tzautoupdate` service startup value to `3`, which is the expected value
    for this workflow.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Set-AutomaticTimeZone--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName           = 'Set-AutomaticTimeZone--Remediate.ps1'
$SolutionName         = 'Set-AutomaticTimeZone'
$ScriptMode           = 'Remediation'
$LocationConsentPath  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
$LocationConsentName  = 'Value'
$LocationConsentValue = 'Allow'
$LocationConsentType  = 'String'
$TimeZoneServicePath  = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$TimeZoneServiceName  = 'Start'
$TimeZoneServiceValue = 3
$TimeZoneServiceType  = 'DWord'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Set-AutomaticTimeZone--Remediate.txt'
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

function Set-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Type
    )

    try {
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
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
    Write-Log -Message 'Writing location consent value for automatic time zone.'
    if (-not (Set-RegistryValue -Path $LocationConsentPath -Name $LocationConsentName -Value $LocationConsentValue -Type $LocationConsentType)) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'Failed to set the location consent registry value.'
    }

    Write-Log -Message 'Writing tzautoupdate service startup value.'
    if (-not (Set-RegistryValue -Path $TimeZoneServicePath -Name $TimeZoneServiceName -Value $TimeZoneServiceValue -Type $TimeZoneServiceType)) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'Failed to set the tzautoupdate startup registry value.'
    }

    $locationValue = Get-RegistryValue -Path $LocationConsentPath -Name $LocationConsentName
    $timeZoneValue = Get-RegistryValue -Path $TimeZoneServicePath -Name $TimeZoneServiceName

    if ($locationValue -ne $LocationConsentValue) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'Location consent verification failed after remediation.'
    }

    if ([int]$timeZoneValue -ne $TimeZoneServiceValue) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'tzautoupdate verification failed after remediation.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Automatic time zone settings were applied successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
