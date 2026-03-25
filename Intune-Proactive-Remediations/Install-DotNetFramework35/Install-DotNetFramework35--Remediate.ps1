<#
.SYNOPSIS
    Enables the .NET Framework 3.5 Windows optional feature.

.DESCRIPTION
    This remediation script uses `Enable-WindowsOptionalFeature` to enable the
    NetFx3 feature on the local operating system.

    It is intended for devices where the feature is still disabled and
    required by legacy applications.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Install-DotNetFramework35--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName    = 'Install-DotNetFramework35--Remediate.ps1'
$SolutionName  = 'Install-DotNetFramework35'
$ScriptMode    = 'Remediation'
$FeatureName   = 'NetFx3'
$ExpectedState = 'Enabled'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Install-DotNetFramework35--Remediate.txt'
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

Write-Log -Message ("Enabling optional feature: {0}" -f $FeatureName)

try {
    Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart -ErrorAction Stop | Out-Null
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop

    if ($feature.State -eq $ExpectedState) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message '.NET Framework 3.5 was enabled successfully.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message (".NET Framework 3.5 did not reach the expected state after remediation. Current state: {0}" -f $feature.State)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to enable .NET Framework 3.5: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
